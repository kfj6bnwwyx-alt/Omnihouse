//
//  RoomDetailView.swift
//  house connect
//
//  Drill-down for a single room. Matches Pencil node `ewnMb`:
//    • Custom header with back chevron, room name, and an overflow menu
//      (rename / delete) — replaces the old .navigationTitle Form chrome.
//    • A "N of M devices active" summary pill with a sparkline icon.
//    • Section header "Devices".
//    • A vertical list of bespoke device row cards — lavender IconChip +
//      name + per-category state subtitle + inline power Toggle for any
//      device that exposes a `.power` capability. Tapping the card body
//      pushes the router via the enclosing NavigationStack's
//      `navigationDestination(for: AccessoryID.self)`.
//    • Floating purple "+" FAB bottom-right that sheets into AddDeviceView
//      — AddDevice currently runs HomeKit's room-agnostic setup flow, so
//      we can't pre-associate the new accessory with this room until the
//      HomeKit setup callback exposes a roomID hook. The FAB still belongs
//      here because the Pencil design treats "add a device" as primarily a
//      room-context affordance.
//
//  Why we replaced the old Form-based layout:
//  ------------------------------------------
//  The previous version used `Form { … }` with a Name TextField, an
//  Accessories section, and a Danger section. It worked, but looked
//  foreign compared to every other screen in the app since Phase 2c's
//  Pencil-driven redesign. This rewrite keeps every action the old screen
//  offered — rename, unassign, delete — behind a header Menu + long-press
//  context menu on each row, so nothing was lost.
//
//  Rename / Delete flow lives in the overflow menu at the top-right.
//  Unassign lives in each row's context menu (long-press). The
//  confirmation dialogs are carried over verbatim from the old version.
//
//  Target: iOS 17+ (uses `@Observable`, `ContentUnavailableView`).
//

import SwiftUI

struct RoomDetailView: View {
    let roomID: String
    let providerID: ProviderID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var showingRename = false
    @State private var draftName: String = ""
    @State private var isSaving = false
    @State private var confirmDelete = false
    @State private var pendingUnassign: Accessory?
    @State private var errorMessage: String?
    @State private var showingAddDevice = false

    /// Live look-up so the view reflects the most recent state from the
    /// provider (post-rename, post-assign, etc.).
    private var room: Room? {
        registry.allRooms.first { $0.id == roomID && $0.provider == providerID }
    }

    /// All accessories that should render in this room — unified
    /// across providers by room NAME rather than by provider-scoped
    /// room ID. So a HomeKit "Den" and a Sonos "Den" both contribute
    /// their accessories to a single Den detail view, matching the
    /// dedupe the rooms list performs.
    ///
    /// Name match is case-insensitive and whitespace-trimmed so
    /// " den " and "Den" collapse together. An accessory with nil
    /// roomID is excluded — we only want accessories that were
    /// actually assigned to *some* room, just from any provider.
    ///
    /// The sort is a stable name-order so reorderings between
    /// providers don't shuffle the list on every refresh.
    private var accessoriesInRoom: [Accessory] {
        let matchingRoomIDs = siblingRoomIDs
        return registry.allAccessories
            .filter {
                guard let rid = $0.roomID else { return false }
                return matchingRoomIDs.contains(rid)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Every room ID (across every provider) whose name matches the
    /// anchor room's name. Used to merge same-named rooms into a
    /// single virtual room view. If the anchor room has gone away
    /// (rename, delete), returns an empty set so the view reads as
    /// empty rather than silently falling back to every accessory.
    private var siblingRoomIDs: Set<String> {
        guard let room else { return [] }
        let key = room.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return Set(
            registry.allRooms
                .filter {
                    $0.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased() == key
                }
                .map(\.id)
        )
    }

    /// "Active" in the summary pill = devices that have a power capability
    /// and are currently ON. Devices with no power state (sensors, cameras,
    /// locks without a unified model) aren't counted toward either bucket
    /// in the numerator, but they still contribute to the denominator so
    /// the user sees the full room size.
    private var activeDeviceCount: Int {
        accessoriesInRoom.filter { $0.isOn == true }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.color.pageBackground.ignoresSafeArea()

            if let room {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerBar(room)
                            .padding(.top, 8)

                        summaryPill(room: room)

                        devicesSection
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 120) // clearance for the FAB
                }
                .refreshable {
                    await withTaskGroup(of: Void.self) { group in
                        for provider in registry.providers {
                            group.addTask { @MainActor in
                                await provider.refresh()
                            }
                        }
                    }
                }

                fab
                    .padding(.trailing, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
            } else {
                ContentUnavailableView("Room unavailable",
                                       systemImage: "exclamationmark.triangle")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            draftName = room?.name ?? ""
        }
        .onChange(of: room?.name ?? "") { _, newValue in
            // Keep the rename draft in sync if the room name changes
            // externally (e.g. the provider publishes a fresh snapshot
            // after another device renames it).
            if !showingRename { draftName = newValue }
        }
        .sheet(isPresented: $showingAddDevice) {
            NavigationStack {
                AddDeviceView()
                    .environment(registry)
            }
        }
        .alert("Rename Room", isPresented: $showingRename) {
            TextField("Room name", text: $draftName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {
                draftName = room?.name ?? ""
            }
            Button("Save") {
                if let room { Task { await commitRename(room) } }
            }
            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a new name for this room.")
        }
        .alert("Operation failed",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }),
               actions: { Button("OK") { errorMessage = nil } },
               message: { Text(errorMessage ?? "") })
        .confirmationDialog(
            "Delete room?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteRoom() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Empty room: simple confirm. Non-empty should be unreachable
            // because the menu item is disabled, but keep the warning as
            // a safety net in case state changes mid-tap.
            if accessoriesInRoom.isEmpty {
                Text("This room will be removed from \(room?.provider.displayLabel ?? "this provider").")
            } else {
                Text("This room still contains accessories. Move them out first.")
            }
        }
        .confirmationDialog(
            "Remove from room?",
            isPresented: Binding(
                get: { pendingUnassign != nil },
                set: { if !$0 { pendingUnassign = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingUnassign
        ) { accessory in
            Button("Remove", role: .destructive) {
                Task { await unassign(accessory) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { accessory in
            Text("\u{201C}\(accessory.name)\u{201D} will no longer be assigned to this room.")
        }
    }

    // MARK: - Header

    private func headerBar(_ room: Room) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.chip,
                                         style: .continuous)
                            .fill(Theme.color.cardFill)
                            .shadow(color: .black.opacity(0.05),
                                    radius: 6, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(Theme.font.sectionHeader)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(room.provider.displayLabel)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(room.name), \(room.provider.displayLabel)")

            Spacer(minLength: 8)

            Menu {
                Button {
                    draftName = room.name
                    showingRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete Room", systemImage: "trash")
                }
                .disabled(!accessoriesInRoom.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.chip,
                                         style: .continuous)
                            .fill(Theme.color.cardFill)
                            .shadow(color: .black.opacity(0.05),
                                    radius: 6, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Room options")
            .accessibilityHint("Shows rename and delete actions")
        }
    }

    // MARK: - Summary pill

    /// Small indicator card: "{N} of {M} devices active" with a spark icon.
    /// Matches the Pencil design's leading pill above the Devices header.
    private func summaryPill(room _: Room) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.color.primary.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(summaryText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text("Tap any device to control it")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Theme.color.cardFill)
                .shadow(color: Color.black.opacity(0.05),
                        radius: 6, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryText)
    }

    private var summaryText: String {
        let total = accessoriesInRoom.count
        if total == 0 { return "No devices in this room yet" }
        return "\(activeDeviceCount) of \(total) device\(total == 1 ? "" : "s") active"
    }

    // MARK: - Devices section

    @ViewBuilder
    private var devicesSection: some View {
        Text("Devices")
            .font(Theme.font.sectionHeader)
            .foregroundStyle(Theme.color.title)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)

        if accessoriesInRoom.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No devices here")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text("Tap the + button below to add a device, or open an existing device and assign it to this room.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .hcCard()
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 12) {
                ForEach(accessoriesInRoom) { accessory in
                    NavigationLink(value: accessory.id) {
                        DeviceRowCard(
                            accessory: accessory,
                            onTogglePower: { isOn in
                                Task { await setPower(isOn, on: accessory) }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(accessory.name), \(accessory.isReachable ? "" : "offline")")
                    .accessibilityHint("Opens device details. Long press for more options.")
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingUnassign = accessory
                        } label: {
                            Label("Remove from Room", systemImage: "minus.circle")
                        }
                        .accessibilityHint("Removes this device from the room")
                    }
                }
            }
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            showingAddDevice = true
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.color.primary)
                    .frame(width: 60, height: 60)
                    .shadow(color: Theme.color.primary.opacity(0.35),
                            radius: 12, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add device to this room")
        .accessibilityHint("Opens device setup")
    }

    // MARK: - Actions

    private func commitRename(_ room: Room) async {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != room.name else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await registry.renameRoom(room, to: trimmed)
        } catch {
            errorMessage = "Could not rename room: \(error)"
            draftName = room.name
        }
    }

    private func unassign(_ accessory: Accessory) async {
        do {
            try await registry.assignAccessory(accessory.id, toRoomID: nil)
        } catch {
            errorMessage = "Could not remove \(accessory.name): \(error)"
        }
    }

    private func deleteRoom() async {
        guard let room else { return }
        do {
            try await registry.deleteRoom(room)
            dismiss()
        } catch {
            errorMessage = "Could not delete room: \(error)"
        }
    }

    private func setPower(_ isOn: Bool, on accessory: Accessory) async {
        do {
            try await registry.execute(.setPower(isOn), on: accessory.id)
        } catch {
            errorMessage = "\(accessory.name): \(error)"
        }
    }
}

// MARK: - Device row card
//
// Bespoke row matching the Pencil "Component/Device Card" (M71ku). Pencil
// renders each card as a white rounded-rect with: lavender IconChip +
// name + per-category state subtitle + trailing purple Toggle. The card
// is also tap-able as a whole — the Toggle is wired as a separate hit
// target so a user trying to flip power doesn't accidentally drill into
// the detail view. Using the native SwiftUI `Toggle` here instead of a
// custom capsule means it inherits accessibility and VoiceOver announces
// it correctly as a switch.

private struct DeviceRowCard: View {
    let accessory: Accessory
    /// Only called when the accessory has a power capability. The parent
    /// resolves "tapped the toggle" into a `.setPower` command.
    let onTogglePower: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            IconChip(systemName: iconName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !accessory.isReachable {
                        Circle()
                            .fill(Theme.color.muted)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text("Offline")
                            .font(Theme.font.cardSubtitle)
                            .foregroundStyle(Theme.color.muted)
                    } else {
                        Text(stateDescription)
                            .font(Theme.font.cardSubtitle)
                            .foregroundStyle(stateColor)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let isOn = accessory.isOn {
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { onTogglePower($0) }
                ))
                .labelsHidden()
                .tint(Theme.color.primary)
                .disabled(!accessory.isReachable)
                .accessibilityLabel("\(accessory.name) power")
                .accessibilityValue(isOn ? "On" : "Off")
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.space.cardPadding)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Theme.color.cardFill)
                .shadow(color: Color.black.opacity(0.05),
                        radius: 6, x: 0, y: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.radius.card,
                                       style: .continuous))
    }

    // MARK: Derived display

    /// SF Symbol chosen by accessory category. We bias toward glyphs that
    /// already ship in iOS 17+ — a few exotic ones like `fan.fill` or
    /// `blinds.horizontal.closed` need iOS 17 minimum, which matches the
    /// project's target.
    private var iconName: String {
        switch accessory.category {
        case .light: "lightbulb.fill"
        case .switch: "switch.2"
        case .outlet: "poweroutlet.type.b.fill"
        case .thermostat: "thermometer.medium"
        case .lock: "lock.fill"
        case .sensor: "sensor.fill"
        case .camera: "video.fill"
        case .fan: "fan.fill"
        case .blinds: "blinds.horizontal.closed"
        case .speaker: "hifispeaker.fill"
        case .television: "tv.fill"
        case .smokeAlarm: "smoke.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Per-category state subtitle. Tries to surface the single most
    /// relevant reading for the category — brightness for lights, target
    /// temperature for thermostats, playback title for speakers, battery
    /// for sensors. Falls back to a plain "On"/"Off" when we don't have a
    /// richer signal, and to the category label for devices that don't
    /// model power at all.
    private var stateDescription: String {
        switch accessory.category {
        case .light:
            if let isOn = accessory.isOn {
                if isOn, let b = accessory.brightness {
                    return "On · \(Int(b * 100))%"
                }
                return isOn ? "On" : "Off"
            }
            return "Light"

        case .thermostat:
            // No hvacMode vocab yet (Tier 2D). Show the current reading
            // and target so the user still sees "is it running?".
            if case .targetTemperature(let targetC) = accessory.capability(of: .targetTemperature) {
                let targetF = Int((targetC * 9.0 / 5.0 + 32.0).rounded())
                if let currentC = accessory.currentTemperature {
                    let currentF = Int((currentC * 9.0 / 5.0 + 32.0).rounded())
                    return "\(currentF)°F · Target \(targetF)°F"
                }
                return "Target \(targetF)°F"
            }
            if let currentC = accessory.currentTemperature {
                let currentF = Int((currentC * 9.0 / 5.0 + 32.0).rounded())
                return "\(currentF)°F"
            }
            return "Thermostat"

        case .speaker:
            if let state = accessory.playbackState {
                switch state {
                case .playing:
                    if let title = accessory.nowPlaying?.title, !title.isEmpty {
                        return "Playing · \(title)"
                    }
                    return "Playing"
                case .paused: return "Paused"
                case .stopped: return "Stopped"
                case .transitioning: return "Loading…"
                case .unknown: return "Idle"
                }
            }
            if let isOn = accessory.isOn { return isOn ? "On" : "Off" }
            return "Speaker"

        case .sensor:
            if case .motionSensor(let detected) = accessory.capability(of: .motionSensor) {
                return detected ? "Motion detected" : "No motion"
            }
            if case .contactSensor(let open) = accessory.capability(of: .contactSensor) {
                return open ? "Open" : "Closed"
            }
            if case .batteryLevel(let p) = accessory.capability(of: .batteryLevel) {
                return "Battery \(p)%"
            }
            return "Sensor"

        case .camera:
            return accessory.isReachable ? "Live" : "Offline"

        case .lock:
            if let isOn = accessory.isOn { return isOn ? "Locked" : "Unlocked" }
            return "Lock"

        case .television:
            // Matches the Frame TV detail screen's tile subtitle: the
            // user wants to see "what's on screen right now" — Art
            // Mode, a specific HDMI input, or a now-playing title.
            // Today we have no such capabilities on the generic
            // Accessory yet, so fall back to on/off.
            if let isOn = accessory.isOn { return isOn ? "On" : "Off" }
            return "TV"

        case .smokeAlarm:
            if let smoke = accessory.isSmokeDetected, smoke { return "Smoke Detected!" }
            if let co = accessory.isCODetected, co { return "CO Detected!" }
            if case .batteryLevel(let p) = accessory.capability(of: .batteryLevel) {
                return "All Clear · Battery \(p)%"
            }
            return "All Clear"

        case .fan, .blinds, .outlet, .switch, .other:
            if let isOn = accessory.isOn { return isOn ? "On" : "Off" }
            return accessory.category.rawValue.capitalized
        }
    }

    /// Color the state subtitle takes on. ON states get the primary
    /// purple; OFF / idle states get the muted subtitle grey. Alert-y
    /// states (motion, door open) get orange to draw the eye.
    private var stateColor: Color {
        switch accessory.category {
        case .sensor:
            if case .motionSensor(let detected) = accessory.capability(of: .motionSensor),
               detected {
                return .orange
            }
            if case .contactSensor(let open) = accessory.capability(of: .contactSensor),
               open {
                return .orange
            }
            return Theme.color.subtitle

        default:
            if accessory.isOn == true { return Theme.color.primary }
            if accessory.isOn == false { return Theme.color.subtitle }
            return Theme.color.subtitle
        }
    }
}

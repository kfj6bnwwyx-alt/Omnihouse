//
//  T3RoomDetailView.swift
//  house connect
//
//  T3/Swiss room detail — indexed device list with pill toggles.
//  Back → Rooms, device rows navigate to type-specific detail.
//
//  Room management (2026-04-21): added rename + delete actions via the
//  "···" menu in the THeader. Rename shows an inline editor with the
//  same focus-and-underline style used in T3CreateRoomSheet. Delete
//  shows a `confirmationDialog` and calls `registry.deleteRoom(_:)`.
//

import SwiftUI

struct T3RoomDetailView: View {
    let roomID: String
    let providerID: ProviderID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(RoomLinkStore.self) private var roomLinkStore
    @Environment(\.dismiss) private var dismiss

    // Rename state
    @State private var showingRename = false
    @State private var renameText   = ""
    @State private var isRenaming   = false
    @State private var renameError: String?
    @FocusState private var renameFocused: Bool

    // Delete state
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false

    private var room: Room? {
        registry.allRooms.first { $0.id == roomID && $0.provider == providerID }
    }

    /// Every (provider, roomID) pair that rolls up into this view:
    /// the primary the user tapped plus every secondary linked to it.
    /// Unlinked rooms return just themselves.
    private var contributingKeys: [RoomKey] {
        let primary = RoomKey(provider: providerID, roomID: roomID)
        return [primary] + roomLinkStore.secondaries(for: primary)
    }

    private var devices: [Accessory] {
        let keys = Set(contributingKeys)
        return registry.allAccessories
            .filter { acc in
                guard let rid = acc.roomID else { return false }
                return keys.contains(RoomKey(provider: acc.id.provider, roomID: rid))
            }
            .sorted { $0.name < $1.name }
    }

    private var activeCount: Int {
        devices.filter { $0.isOn == true }.count
    }

    private var providers: [String] {
        Array(Set(devices.map { $0.id.provider.displayLabel }))
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header — back + room index on the right + "···" menu
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                T3IconImage(systemName: "chevron.left")
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(T3.ink)
                                TLabel(text: "Rooms", color: T3.ink)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        HStack(spacing: 16) {
                            TLabel(text: "Room \(String(format: "%02d", roomIndex + 1))")

                            Menu {
                                Button {
                                    renameText = room?.name ?? ""
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        showingRename = true
                                    }
                                } label: {
                                    Label("Rename Room", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    showingDeleteConfirm = true
                                } label: {
                                    Label("Delete Room", systemImage: "trash")
                                }
                            } label: {
                                T3IconImage(systemName: "ellipsis")
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(T3.ink)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Room actions")
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 8)

                    // Inline rename editor — slides in when showingRename is true.
                    if showingRename {
                        renamePanel
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Title block
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if activeCount > 0 { TDot(size: 8) }
                            TLabel(text: activeCount > 0 ? "Active" : "Idle")
                        }

                        Text(room?.name ?? "Room")
                            .font(T3.inter(42, weight: .medium))
                            .tracking(-1.4)
                            .foregroundStyle(T3.ink)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.7)
                            .padding(.top, 8)

                        Text("\(activeCount) of \(devices.count) devices on · \(providers.joined(separator: " + "))")
                            .font(T3.inter(13, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                    TRule()

                    // Devices section
                    TSectionHead(title: "Devices", count: String(format: "%02d", devices.count))

                    if devices.isEmpty {
                        T3EmptyState(
                            iconSystemName: "plus.rectangle.on.folder",
                            title: "No devices in this room",
                            subtitle: "Assign devices here from the Devices tab.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        ForEach(Array(devices.enumerated()), id: \.element.id) { i, device in
                            T3DeviceRow(device: device, index: i, isLast: i == devices.count - 1)
                        }
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete \"\(room?.name ?? "Room")\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Room", role: .destructive) {
                Task { await deleteRoom() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if devices.isEmpty {
                Text("This room has no devices and will be permanently removed.")
            } else {
                Text("This room has \(devices.count) device\(devices.count == 1 ? "" : "s"). They'll become unassigned. The room will be permanently removed.")
            }
        }
    }

    // MARK: - Rename panel

    private var renamePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TRule()

            VStack(alignment: .leading, spacing: 8) {
                TLabel(text: "RENAME ROOM")

                TextField(room?.name ?? "Room name", text: $renameText)
                    .autocorrectionDisabled()
                    .focused($renameFocused)
                    .font(T3.inter(20, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .submitLabel(.done)
                    .onSubmit { Task { await commitRename() } }
                    .onAppear { renameFocused = true }

                Rectangle()
                    .fill(renameFocused ? T3.accent : T3.rule)
                    .frame(height: renameFocused ? 1.5 : 1)
                    .animation(.easeOut(duration: 0.18), value: renameFocused)

                if let error = renameError {
                    Text(error)
                        .font(T3.mono(11))
                        .foregroundStyle(T3.danger)
                        .tracking(0.6)
                }
            }
            .padding(.horizontal, T3.screenPadding)

            HStack(spacing: 10) {
                ghostButton(title: "CANCEL") {
                    withAnimation(.easeOut(duration: 0.18)) { showingRename = false }
                    renameError = nil
                }
                ghostButton(
                    title: isRenaming ? "SAVING…" : "SAVE",
                    disabled: isRenaming || renameText.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    Task { await commitRename() }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.bottom, 14)

            TRule()
        }
        .background(T3.panel)
    }

    private func ghostButton(
        title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(T3.mono(11))
                .tracking(1.6)
                .foregroundStyle(disabled ? T3.sub : T3.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Actions

    private func commitRename() async {
        guard let room else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != room.name else {
            withAnimation(.easeOut(duration: 0.18)) { showingRename = false }
            return
        }

        isRenaming = true
        renameError = nil
        defer { isRenaming = false }

        do {
            try await registry.renameRoom(room, to: trimmed)
            withAnimation(.easeOut(duration: 0.18)) { showingRename = false }
        } catch {
            renameError = "Could not rename: \(error.localizedDescription)"
        }
    }

    private func deleteRoom() async {
        guard let room else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await registry.deleteRoom(room)
            dismiss()
        } catch {
            // If delete fails, stay on the screen — the room is still live.
            // (The confirmationDialog is already dismissed by the time we
            // hear back, so we can't easily re-show it. A future pass
            // could post a Toast.)
        }
    }

    // MARK: - Helpers

    private var roomIndex: Int {
        registry.allRooms.firstIndex { $0.id == roomID } ?? 0
    }
}

// MARK: - Device Row

struct T3DeviceRow: View {
    let device: Accessory
    let index: Int
    let isLast: Bool

    @Environment(ProviderRegistry.self) private var registry
    @State private var isOn: Bool

    init(device: Accessory, index: Int, isLast: Bool) {
        self.device = device
        self.index = index
        self.isLast = isLast
        self._isOn = State(initialValue: device.isOn ?? false)
    }

    var body: some View {
        HStack(spacing: 14) {
            TLabel(text: String(format: "%02d", index + 1))
                .frame(width: 28)

            T3IconImage(systemName: categoryIcon(device.category))
                .frame(width: 18, height: 18)
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(T3.inter(15, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    if device.isOn == true { TDot(size: 5) }
                    Text(stateText(device))
                        .font(T3.inter(11, weight: .regular))
                        .foregroundStyle(T3.sub)
                    Text("·")
                        .foregroundStyle(T3.sub)
                    Text(device.id.provider.displayLabel.uppercased())
                        .font(T3.mono(10))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                }
            }

            Spacer()

            TPill(isOn: $isOn)
                .onChange(of: isOn) { _, newValue in
                    Task {
                        try? await registry.execute(.setPower(newValue), on: device.id)
                    }
                }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) {
            if isLast { TRule() }
        }
    }

    private func stateText(_ device: Accessory) -> String {
        if let brightness = device.brightness {
            return device.isOn == true ? "ON · \(Int(brightness * 100))%" : "OFF"
        }
        if device.category == .thermostat {
            let current = device.currentTemperature.map { "\(Int($0 * 9/5 + 32))°" } ?? "—"
            return current
        }
        if device.category == .lock {
            return device.isOn == true ? "UNLOCKED" : "LOCKED"
        }
        return device.isOn == true ? "ON" : "OFF"
    }

    private func categoryIcon(_ cat: Accessory.Category) -> String {
        switch cat {
        case .light: "lightbulb"
        case .thermostat: "thermometer.medium"
        case .lock: "lock.fill"
        case .speaker: "hifispeaker"
        case .camera: "video.fill"
        case .fan: "fan"
        case .blinds: "blinds.horizontal.closed"
        case .switch, .outlet: "poweroutlet.type.b.fill"
        case .sensor: "sensor.fill"
        case .television: "tv"
        case .appleTV: "tv"
        case .smokeAlarm: "smoke.fill"
        case .other: "questionmark.app"
        }
    }
}

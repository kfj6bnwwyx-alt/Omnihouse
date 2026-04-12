//
//  SmokeAlarmDetailView.swift
//  house connect
//
//  Bespoke detail screen for Nest Protect-style smoke/CO alarms. Matches
//  Pencil node `mATCa`. This is the calm "All Clear" state — the Pencil
//  file also has a full red-screen emergency alert (`6kaLS`) which will
//  land in Chunk D once the Nest provider + Critical Alerts entitlement
//  are in place.
//
//  SCAFFOLD — no real Nest provider exists yet. Every data point below
//  falls back to static placeholders because our unified vocabulary
//  does not yet model smoke/CO sensor kinds. That means this screen is
//  reachable through the router's `.sensor` branch, but today it only
//  shows up if the user has a Phase 6 Nest device. Keep the UI intact
//  so we can iterate without a provider.
//
//  TODO when Nest provider lands:
//    - Add `smokeDetected(Bool)` + `coDetected(Bool)` capability cases.
//    - Read batteryLevel(percent:) from capabilities instead of hardcode.
//    - Wire "Run Self-Test" to a new AccessoryCommand.selfTest case.
//    - Swap the green shield for a red-screen full-bleed layout when
//      either smoke or CO is detected (Chunk D).
//

import SwiftUI

struct SmokeAlarmDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(SmokeAlarmEventStore.self) private var eventStore
    #if os(iOS)
    @Environment(SmokeAlertController.self) private var alertController
    #endif

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    /// Read a battery reading off the capability list if the provider
    /// publishes one. Falls back to 87% so the mock reads correctly
    /// before a real Nest provider lands.
    private var batteryPercent: Int {
        guard let accessory else { return 87 }
        if case .batteryLevel(let p) = accessory.capability(of: .batteryLevel) {
            return p
        }
        return 87
    }

    /// Smoke status — driven by the `smokeDetected` capability when
    /// present, else falls back to "Normal" (green).
    private var smokeStatus: (value: String, color: Color) {
        guard let detected = accessory?.isSmokeDetected else {
            return ("Normal", .green)
        }
        return detected ? ("Detected!", .red) : ("Normal", .green)
    }

    /// CO status — driven by the `coDetected` capability when present.
    private var coStatus: (value: String, color: Color) {
        guard let detected = accessory?.isCODetected else {
            return ("Normal", .green)
        }
        return detected ? ("Detected!", .red) : ("Normal", .green)
    }

    /// Whether the device reports real smoke/CO capabilities (vs the
    /// old hardcoded placeholders). When true, the simulation card
    /// is hidden since the device has real detection.
    private var hasRealDetection: Bool {
        accessory?.isSmokeDetected != nil || accessory?.isCODetected != nil
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(spacing: 20) {
                        DeviceDetailHeader(
                            title: accessory.name,
                            subtitle: roomName,
                            isOn: nil,
                            onTogglePower: { _ in }
                        )
                        .padding(.top, 8)

                        allClearCard
                        statusRowsCard
                        selfTestButton
                        #if os(iOS)
                        simulationCard(for: accessory)
                        #endif
                        recentEventsCard
                        RemoveDeviceSection(accessoryID: accessoryID)
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "Alarm unavailable",
                    systemImage: "exclamationmark.shield"
                )
                .accessibilityLabel("Smoke alarm is unavailable")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        #if os(iOS)
        .fullScreenCover(isPresented: Binding(
            get: { alertController.isActive },
            set: { if !$0 { Task { await alertController.end(reason: .simulationStopped) } } }
        )) {
            SmokeAlarmAlertView(
                roomName: roomName ?? "Unknown Room",
                deviceName: accessory?.name ?? "Smoke Alarm",
                detectedAt: Date(),
                onSilence: {
                    Task { await alertController.end(reason: .simulationStopped) }
                },
                onDismiss: {
                    Task { await alertController.end(reason: .simulationStopped) }
                }
            )
        }
        #endif
    }

    // MARK: - All clear card

    private var allClearCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color.green)
            }
            Text("All Clear")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.color.title)
            Text("No smoke or carbon monoxide detected")
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.subtitle)
        }
        .frame(maxWidth: .infinity)
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Smoke alarm status: All Clear. No smoke or carbon monoxide detected")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Status rows card (Smoke / CO / Battery)

    private var statusRowsCard: some View {
        VStack(spacing: 0) {
            statusRow(icon: "smoke.fill",
                      title: "Smoke",
                      value: smokeStatus.value,
                      valueColor: smokeStatus.color)
            Divider().padding(.leading, 56)
            statusRow(icon: "aqi.medium",
                      title: "Carbon Monoxide",
                      value: coStatus.value,
                      valueColor: coStatus.color)
            Divider().padding(.leading, 56)
            statusRow(icon: "battery.75percent",
                      title: "Battery",
                      value: "\(batteryPercent)%",
                      valueColor: batteryPercent >= 20 ? .green : .orange)
            // Humidity row — only shown when the capability is present.
            if let humidity = accessory?.humidityPercent {
                Divider().padding(.leading, 56)
                statusRow(icon: "humidity.fill",
                          title: "Humidity",
                          value: "\(humidity)%",
                          valueColor: Theme.color.iconChipGlyph)
            }
        }
        .hcCard(padding: 0)
    }

    private func statusRow(
        icon: String,
        title: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.color.title)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(valueColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(valueColor.opacity(0.12)))
        }
        .padding(.horizontal, Theme.space.cardPadding)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Self test

    private var selfTestButton: some View {
        HStack(spacing: 12) {
            IconChip(systemName: "play.circle.fill", size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Run Self-Test")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text("Requires real Nest integration")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            Text("Soon")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.color.primary.opacity(0.12)))
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run Self-Test. Currently unavailable, requires real Nest integration")
        .accessibilityHint("Self-test will be available once the Nest provider is connected")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Simulation (dev-only path until Nest provider lands)

    #if os(iOS)
    /// Dev-only affordance that runs the full smoke-alert Live Activity
    /// pipeline without a real Nest provider. See `SmokeAlertController`.
    /// This card is hidden automatically once a real provider exists by
    /// gating it on the lack of real smoke capabilities on the accessory,
    /// but for now it always renders because no provider reports smoke.
    private func simulationCard(for accessory: Accessory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconChip(systemName: "exclamationmark.triangle.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simulate Alert")
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text("Runs the full Live Activity pipeline for preview")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.color.subtitle)
                }
                Spacer()
            }

            if alertController.isActive {
                Button(role: .destructive) {
                    Task { await alertController.end(reason: .simulationStopped) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Stop Simulation")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.red))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop smoke alarm simulation")
                .accessibilityHint("Ends the active Live Activity alert simulation")
            } else {
                Button {
                    Task {
                        await alertController.simulate(
                            using: accessory,
                            roomName: roomName
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Simulate Alert")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.color.primary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Simulate smoke alarm alert")
                .accessibilityHint("Starts a Live Activity alert simulation that escalates to critical after 5 seconds and auto-ends after 30 seconds")
            }

            Text("Requires the HouseConnectWidgets target to be added in Xcode — see HouseConnectWidgets/README.md. Once added, this button starts a warning-level Live Activity, escalates to critical after 5s, and auto-ends after 30s.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.color.muted)
        }
        .hcCard()
    }
    #endif

    // MARK: - Recent events

    private var recentEventsCard: some View {
        let events = eventStore.events(for: accessoryID.nativeID)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
                .accessibilityAddTraits(.isHeader)

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.color.muted)
                    Text("No events recorded yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.color.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(events.prefix(5)) { event in
                    eventRow(
                        icon: event.iconName,
                        title: event.title,
                        time: event.relativeTime,
                        color: colorForEvent(event)
                    )
                }
            }
        }
        .hcCard()
    }

    private func colorForEvent(_ event: SmokeAlarmEvent) -> Color {
        switch event.iconColor {
        case "green": .green
        case "red": .red
        case "orange": .orange
        case "blue": Theme.color.primary
        default: Theme.color.iconChipGlyph
        }
    }

    private func eventRow(
        icon: String,
        title: String,
        time: String,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.title)
            Spacer()
            Text(time)
                .font(.system(size: 12))
                .foregroundStyle(Theme.color.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(time)")
    }
}

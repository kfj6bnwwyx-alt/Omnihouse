//
//  ThermostatDetailView.swift
//  house connect
//
//  Bespoke detail screen for thermostats. Matches Pencil node `gpAyI`.
//  Layout, top to bottom:
//    • Shared DeviceDetailHeader (back + name + room + power pill)
//    • Big circular temperature card — huge current temp, small target
//      delta, decrement/increment chevrons, a colored "bar graph" strip
//      showing where the setpoint sits relative to a 60-90°F range.
//    • Mode chips row: Heat / Cool / Auto / Off (only the current mode
//      highlights in purple).
//    • Stats card: Indoor humidity, Outdoor temp, Outdoor humidity. All
//      placeholder until we add those capabilities.
//    • Day / Night schedule preview card.
//
//  Everything is unit-aware: we store/transmit temperatures in Celsius
//  through the capability layer and format as Fahrenheit on-screen
//  because the Pencil design uses °F. A preference flip is a later pass.
//

import SwiftUI

struct ThermostatDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @AppStorage("appearance.tempUnit") private var tempUnitRaw: String = "celsius"

    @State private var errorMessage: String?
    /// Draft setpoint while the user is tapping +/-. Flushed after a
    /// short debounce so we don't hammer the provider with one command
    /// per tap.
    @State private var targetDraftCelsius: Double?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    private var useFahrenheit: Bool { tempUnitRaw != "celsius" }

    /// Unit suffix based on preference.
    private var unitSuffix: String { useFahrenheit ? "°F" : "°C" }

    /// Display-unit range for the bar strip. 60-90°F or ~15-32°C.
    private var displayRange: ClosedRange<Double> {
        useFahrenheit ? 60...90 : 15...32
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
                            isOn: accessory.isOn,
                            onTogglePower: { on in
                                Task { await send(.setPower(on), accessory: accessory) }
                            }
                        )
                        .padding(.top, 8)

                        bigTempCard(for: accessory)
                        modeChipsCard(for: accessory)
                        statsCard(for: accessory)
                        scheduleCard
                        RemoveDeviceSection(accessoryID: accessoryID)
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "Thermostat unavailable",
                    systemImage: "thermometer.medium.slash"
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Operation failed",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }),
               actions: { Button("OK") { errorMessage = nil } },
               message: { Text(errorMessage ?? "") })
    }

    // MARK: - Big temperature card

    /// Convert Celsius to the user's preferred display unit.
    private func displayTemp(_ celsius: Double) -> Double {
        useFahrenheit ? celsiusToFahrenheit(celsius) : celsius
    }

    private func bigTempCard(for accessory: Accessory) -> some View {
        let currentDisplay = accessory.currentTemperature.map(displayTemp)
        let targetC = targetDraftCelsius ?? capabilityTargetC(for: accessory)
        let targetDisplay = targetC.map(displayTemp)

        return VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Button {
                    nudgeTarget(by: -1, accessory: accessory)
                } label: {
                    bigNudge(system: "minus")
                }
                .buttonStyle(.plain)
                .disabled(targetC == nil || !accessory.isReachable)
                .accessibilityLabel("Decrease temperature")
                .accessibilityHint(targetDisplay.map { "Current target is \(Int($0.rounded()))\(unitSuffix)" } ?? "No target set")

                VStack(spacing: 4) {
                    if let currentDisplay {
                        Text("\(Int(currentDisplay.rounded()))°")
                            .font(.system(size: 84, weight: .heavy))
                            .foregroundStyle(Theme.color.title)
                            .monospacedDigit()
                    } else {
                        Text("—°")
                            .font(.system(size: 84, weight: .heavy))
                            .foregroundStyle(Theme.color.muted)
                    }
                    Text(currentDisplay != nil ? "Current Temperature" : "No reading")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.color.subtitle)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(currentDisplay.map { "Current temperature, \(Int($0.rounded()))\(unitSuffix)" } ?? "No temperature reading")

                Button {
                    nudgeTarget(by: 1, accessory: accessory)
                } label: {
                    bigNudge(system: "plus")
                }
                .buttonStyle(.plain)
                .disabled(targetC == nil || !accessory.isReachable)
                .accessibilityLabel("Increase temperature")
                .accessibilityHint(targetDisplay.map { "Current target is \(Int($0.rounded()))\(unitSuffix)" } ?? "No target set")
            }

            // Target chip
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 12, weight: .bold))
                Text(targetDisplay.map { "Target \(Int($0.rounded()))\(unitSuffix)" } ?? "No target")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.color.iconChipGlyph)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.color.iconChipFill))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(targetDisplay.map { "Target temperature, \(Int($0.rounded()))\(unitSuffix)" } ?? "No target temperature set")

            // Bar graph strip — purple fill up to the setpoint position
            // within the display range.
            temperatureBar(targetDisplay: targetDisplay)
        }
        .frame(maxWidth: .infinity)
        .hcCard()
    }

    private func bigNudge(system: String) -> some View {
        ZStack {
            Circle()
                .fill(Theme.color.iconChipFill)
                .frame(width: 48, height: 48)
            Image(systemName: system)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.color.iconChipGlyph)
        }
    }

    private func temperatureBar(targetDisplay: Double?) -> some View {
        GeometryReader { geo in
            let fraction: Double = {
                guard let targetDisplay else { return 0 }
                let clamped = min(max(targetDisplay, displayRange.lowerBound),
                                  displayRange.upperBound)
                let span = displayRange.upperBound - displayRange.lowerBound
                return (clamped - displayRange.lowerBound) / span
            }()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.color.divider)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.color.primary.opacity(0.7),
                                     Theme.color.primary],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 10)
        .overlay(alignment: .topLeading) {
            Text("\(Int(displayRange.lowerBound))°")
                .font(.system(size: 10))
                .foregroundStyle(Theme.color.muted)
                .offset(y: 14)
        }
        .overlay(alignment: .topTrailing) {
            Text("\(Int(displayRange.upperBound))°")
                .font(.system(size: 10))
                .foregroundStyle(Theme.color.muted)
                .offset(y: 14)
        }
        .padding(.bottom, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(targetDisplay.map { "Temperature bar, target at \(Int($0.rounded()))\(unitSuffix) within range \(Int(displayRange.lowerBound)) to \(Int(displayRange.upperBound))" } ?? "Temperature bar, no target set")
    }

    // MARK: - Mode chips

    /// Heat/Cool/Auto/Off selector wired to the `.hvacMode` capability.
    /// Each chip fires `.setHVACMode(_)`. If the accessory doesn't publish
    /// a mode yet (pre-mapping, or provider without the capability) the
    /// chips still render but none is highlighted and taps fall back to
    /// sending a best-effort command — provider will reject with
    /// `unsupportedCommand` in that case and the alert will surface.
    private func modeChipsCard(for accessory: Accessory) -> some View {
        let current = accessory.hvacMode
        return HStack(spacing: 8) {
            modeChip(mode: .heat,
                     label: "Heat",
                     system: "flame.fill",
                     isSelected: current == .heat,
                     accessory: accessory)
            modeChip(mode: .cool,
                     label: "Cool",
                     system: "snowflake",
                     isSelected: current == .cool,
                     accessory: accessory)
            modeChip(mode: .auto,
                     label: "Auto",
                     system: "arrow.triangle.2.circlepath",
                     isSelected: current == .auto,
                     accessory: accessory)
            modeChip(mode: .off,
                     label: "Off",
                     system: "power",
                     isSelected: current == .off,
                     accessory: accessory)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("HVAC mode selector")
        .hcCard()
    }

    private func modeChip(
        mode: HVACMode,
        label: String,
        system: String,
        isSelected: Bool,
        accessory: Accessory
    ) -> some View {
        Button {
            Task { await send(.setHVACMode(mode), accessory: accessory) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Theme.color.subtitle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                    .fill(isSelected ? Theme.color.primary : Theme.color.iconChipFill)
            )
        }
        .buttonStyle(.plain)
        .disabled(!accessory.isReachable)
        .accessibilityLabel("\(label) mode")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Currently active mode" : "Double tap to switch to \(label) mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Stats card

    private func statsCard(for accessory: Accessory) -> some View {
        HStack(spacing: 12) {
            statTile(icon: "thermometer.medium",
                     label: "Indoor",
                     value: accessory.currentTemperature
                        .map { "\(Int(displayTemp($0).rounded()))\(unitSuffix)" } ?? "—")
            statTile(icon: "sun.max.fill",
                     label: "Outdoor",
                     value: "—",
                     hint: "Not available")
            statTile(icon: "humidity.fill",
                     label: "Humidity",
                     value: "—",
                     hint: "Not available")
        }
    }

    private func statTile(icon: String, label: String, value: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            IconChip(systemName: icon, size: 32)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(value == "—" ? Theme.color.muted : Theme.color.title)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.color.subtitle)
            if let hint {
                Text(hint)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value == "—" ? "not available" : value)")
    }

    // MARK: - Schedule card

    /// Schedule card — shows a placeholder until per-device thermostat
    /// scheduling is built (Phase 3b automation story). The previous
    /// hardcoded Day=22°/Night=20° values were misleading.
    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedule")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Spacer()
            }

            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.color.muted)
                Text("Thermostat schedules coming soon")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.color.subtitle)
                Text("Day/night temperature programs will be configurable in a future update.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.color.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schedule. Thermostat schedules coming soon. Day and night temperature programs will be configurable in a future update.")
    }

    private func scheduleRow(system: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            IconChip(systemName: system, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.subtitle)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                .fill(Theme.color.iconChipFill.opacity(0.5))
        )
    }

    // MARK: - Target handling

    /// Pull the live target temperature off the capability list if the
    /// provider publishes it. Returns nil if the accessory doesn't expose
    /// a target setpoint at all.
    private func capabilityTargetC(for accessory: Accessory) -> Double? {
        if case .targetTemperature(let c) = accessory.capability(of: .targetTemperature) {
            return c
        }
        return nil
    }

    /// Nudge target by one display-unit step: ±1°F or ±0.5°C.
    private func nudgeTarget(by direction: Double, accessory: Accessory) {
        let base = targetDraftCelsius ?? capabilityTargetC(for: accessory) ?? 21
        let newC: Double
        if useFahrenheit {
            let baseF = celsiusToFahrenheit(base)
            newC = fahrenheitToCelsius(baseF + direction)
        } else {
            newC = base + (direction * 0.5)
        }
        targetDraftCelsius = newC
        Task {
            await send(.setTargetTemperature(newC), accessory: accessory)
            targetDraftCelsius = nil
        }
    }

    // MARK: - Actions

    private func send(_ command: AccessoryCommand, accessory: Accessory) async {
        do {
            try await registry.execute(command, on: accessory.id)
        } catch {
            errorMessage = "\(accessory.name): \(error)"
        }
    }

    // MARK: - Unit conversion

    private func celsiusToFahrenheit(_ c: Double) -> Double {
        c * 9.0 / 5.0 + 32.0
    }
    private func fahrenheitToCelsius(_ f: Double) -> Double {
        (f - 32.0) * 5.0 / 9.0
    }
}

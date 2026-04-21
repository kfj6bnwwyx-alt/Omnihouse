//
//  T3ThermostatView.swift
//  house connect
//
//  T3/Swiss thermostat — 168px temperature number with orange degree glyph,
//  tick scale with dot indicator, mode selector, conditions grid, schedule.
//  Matches Claude Design handoff T3Thermo component.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3ThermostatView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var targetDraft: Int?
    @State private var selectedMode: HVACMode = .heat
    @State private var repeatTimer: Timer?
    @State private var didRepeat: Bool = false
    @State private var toast: Toast?

    /// Mirrors the Appearance setting — all temperature displays follow this unit.
    @AppStorage("appearance.tempUnit") private var tempUnit: String = "celsius"

    private var useFahrenheit: Bool { tempUnit == "fahrenheit" }

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "Room" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "Room"
    }

    private var modeHeaderLabel: String {
        switch selectedMode {
        case .heat: return "HEATING"
        case .cool: return "COOLING"
        case .auto: return "AUTO"
        case .off:  return "OFF"
        }
    }

    private func toDisplay(_ celsius: Double) -> Int {
        useFahrenheit
            ? Int((celsius * 9.0 / 5.0 + 32.0).rounded())
            : Int(celsius.rounded())
    }

    private var currentTemp: Int {
        guard let c = accessory?.currentTemperature else { return useFahrenheit ? 68 : 20 }
        return toDisplay(c)
    }

    private var targetTemp: Int {
        if let draft = targetDraft { return draft }
        guard let accessory,
              case .targetTemperature(let c) = accessory.capability(of: .targetTemperature)
        else { return useFahrenheit ? 71 : 22 }
        return toDisplay(c)
    }

    /// Temperature range for the tick scale — Fahrenheit (60–90) or Celsius (15–32).
    private var range: (Int, Int) { useFahrenheit ? (60, 90) : (15, 32) }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    THeader(
                        backLabel: roomName,
                        rightLabel: modeHeaderLabel,
                        showDot: accessory?.isReachable ?? false,
                        onBack: { dismiss() }
                    )

                    // Huge number
                    VStack(alignment: .leading, spacing: 0) {
                        TLabel(text: "Interior")
                            .accessibilityHidden(true)

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(currentTemp)")
                                .font(T3.inter(168, weight: .light))
                                .tracking(-8)
                                .foregroundStyle(T3.ink)
                                .monospacedDigit()

                            Text("°")
                                .font(T3.inter(64, weight: .regular))
                                .foregroundStyle(T3.accent)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Interior temperature \(currentTemp) degrees")

                        // Target + buttons
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                TLabel(text: "Target")
                                Text("\(targetTemp)°")
                                    .font(T3.inter(22, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                    .monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Target temperature \(targetTemp) degrees")

                            Spacer()

                            HStack(spacing: 10) {
                                // Minus button — outlined circle
                                adjustButton(delta: -1) {
                                    Circle()
                                        .stroke(T3.rule, lineWidth: 1)
                                        .fill(T3.panel)
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            T3IconImage(systemName: "minus")
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(T3.ink)
                                        )
                                }
                                .accessibilityLabel("Decrease target temperature")
                                .accessibilityAddTraits(.isButton)

                                // Plus button — orange filled circle
                                adjustButton(delta: 1) {
                                    Circle()
                                        .fill(T3.accent)
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            T3IconImage(systemName: "plus")
                                                .frame(width: 18, height: 18)
                                                .foregroundStyle(T3.page)
                                        )
                                }
                                .accessibilityLabel("Increase target temperature")
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 8)

                    // Tick scale
                    tickScale
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 20)

                    TRule()

                    // Mode selector
                    modeSelector

                    TRule()

                    // Conditions grid
                    conditionsGrid

                    TRule()

                    // Schedule
                    scheduleSection

                    TRule()

                    // History row — navigates into the event timeline view.
                    NavigationLink {
                        T3ThermostatHistoryView(
                            entityID: accessoryID.nativeID,
                            name: accessory?.name ?? "Thermostat"
                        )
                    } label: {
                        HStack {
                            T3IconImage(systemName: "clock")
                                .frame(width: 16, height: 16)
                                .foregroundStyle(T3.ink)
                                .accessibilityHidden(true)
                            Text("History")
                                .font(T3.inter(14, weight: .medium))
                                .foregroundStyle(T3.ink)
                            Spacer()
                            T3IconImage(systemName: "chevron.right")
                                .frame(width: 12, height: 12)
                                .foregroundStyle(T3.sub)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.t3Row)
                    .accessibilityLabel("View temperature history")
                    .accessibilityAddTraits(.isButton)

                    TRule()

                    TSectionHead(title: "Device")
                    RemoveDeviceSection(accessoryID: accessoryID)

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast, duration: 4)
        .onAppear {
            if let mode = accessory?.hvacMode {
                selectedMode = mode
            }
        }
        // Re-sync mode if a live HA push changes the accessory while the
        // view is open. Guard against overwriting an in-flight user tap —
        // `targetDraft` being non-nil means the user is actively adjusting.
        .onChange(of: accessory?.hvacMode) { _, newMode in
            guard let newMode, targetDraft == nil else { return }
            selectedMode = newMode
        }
    }

    // MARK: - Tick Scale

    private var tickScale: some View {
        let pct = Double(targetTemp - range.0) / Double(range.1 - range.0)
        return VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                // Ticks
                GeometryReader { geo in
                    ForEach(0..<31, id: \.self) { i in
                        let f = Double(i) / 30.0
                        let major = i % 5 == 0
                        let on = f <= pct
                        Rectangle()
                            .fill(on ? T3.ink : T3.rule)
                            .frame(width: 1, height: major ? 14 : 7)
                            .position(x: f * geo.size.width, y: major ? 7 : 3.5)
                    }

                    // Dot indicator
                    TDot(size: 10)
                        .position(x: pct * geo.size.width, y: 22)
                }
                .frame(height: 28)
            }

            HStack {
                TLabel(text: "\(range.0)°")
                Spacer()
                TLabel(text: "\((range.0 + range.1) / 2)°")
                Spacer()
                TLabel(text: "\(range.1)°")
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            TLabel(text: "Mode")
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 10)

            HStack(spacing: 6) {
                ForEach([
                    (HVACMode.heat, "Heat", "flame"),
                    (.cool, "Cool", "snowflake"),
                    (.auto, "Auto", "arrow.2.squarepath"),
                    (.off, "Off", "power"),
                ], id: \.0) { mode, label, icon in
                    Button {
                        let previousMode = selectedMode
                        selectedMode = mode
                        Task { @MainActor in
                            await T3ActionFeedback.perform(
                                action: { try await registry.execute(.setHVACMode(mode), on: accessoryID) },
                                onFailure: { selectedMode = previousMode },
                                toast: { toast = .error("Couldn't change mode") },
                                errorDescription: "Thermostat mode"
                            )
                        }
                    } label: {
                        VStack(spacing: 4) {
                            T3IconImage(systemName: icon)
                                .frame(width: 14, height: 14)
                                .foregroundStyle(selectedMode == mode ? T3.page : T3.ink)
                                .accessibilityHidden(true)
                            Text(label)
                                .font(T3.inter(11, weight: .medium))
                                .foregroundStyle(selectedMode == mode ? T3.page : T3.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: T3.segmentCellRadius)
                                .fill(selectedMode == mode ? T3.ink : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) mode")
                    .accessibilityAddTraits(selectedMode == mode ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: T3.segmentRadius)
                    .fill(T3.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: T3.segmentRadius)
                            .stroke(T3.rule, lineWidth: 1)
                    )
            )
            .padding(.horizontal, T3.screenPadding)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Conditions Grid

    private var conditionsGrid: some View {
        // Indoor humidity comes from the accessory's humidity capability
        // (populated by HA if the thermostat entity exposes it — e.g.
        // some Ecobee / Honeywell devices). Outdoor values require a
        // separate weather integration not yet in scope; show "—" so we
        // don't display stale hardcoded numbers.
        let indoorHum: String = accessory?.humidityPercent.map { "\($0)%" } ?? "—"
        return HStack(spacing: 18) {
            conditionCell(label: "Int Hum", value: indoorHum)
            conditionCell(label: "Out Temp", value: "—")
            conditionCell(label: "Out Hum", value: "—")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 18)
    }

    private func conditionCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(26, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(T3.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        let schedule: [(String, String, Int)] = [
            ("MORNING", "06:00", 70),
            ("DAY", "08:00", 68),
            ("EVENING", "17:30", 72),
            ("NIGHT", "22:00", 65),
        ]

        return VStack(spacing: 0) {
            TSectionHead(title: "Schedule", count: "Weekday")

            ForEach(Array(schedule.enumerated()), id: \.offset) { i, entry in
                HStack {
                    TLabel(text: entry.0, color: T3.ink)
                        .frame(width: 100, alignment: .leading)

                    Text(entry.1)
                        .font(T3.mono(12))
                        .foregroundStyle(T3.sub)
                        .monospacedDigit()

                    Spacer()

                    Text("\(entry.2)°")
                        .font(T3.inter(18, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .monospacedDigit()
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) {
                    if i == schedule.count - 1 { TRule() }
                }
            }
        }
    }

    // MARK: - Adjust Button (tap or long-press repeat)

    @ViewBuilder
    private func adjustButton<Label: View>(delta: Int, @ViewBuilder label: () -> Label) -> some View {
        let view = label()
        view
            .contentShape(Circle())
            .onTapGesture {
                // Only fire single-tap if a repeat didn't already occur
                guard !didRepeat else {
                    didRepeat = false
                    return
                }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                adjustTarget(by: delta)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: T3.LongPress.medium)
                    .onEnded { _ in
                        beginRepeat(delta: delta)
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        endRepeatIfActive()
                    }
            )
    }

    private func beginRepeat(delta: Int) {
        didRepeat = true
        repeatTimer?.invalidate()
        // Fire first tick immediately
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        adjustTarget(by: delta)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            adjustTarget(by: delta)
        }
    }

    private func endRepeatIfActive() {
        guard repeatTimer != nil else { return }
        repeatTimer?.invalidate()
        repeatTimer = nil
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    // MARK: - Actions

    private func adjustTarget(by delta: Int) {
        let previousTarget = targetTemp
        let newTarget = targetTemp + delta
        guard newTarget >= range.0 && newTarget <= range.1 else { return }
        targetDraft = newTarget
        let celsius = useFahrenheit
            ? Double(newTarget - 32) * 5.0 / 9.0
            : Double(newTarget)
        Task { @MainActor in
            await T3ActionFeedback.perform(
                action: { try await registry.execute(.setTargetTemperature(celsius), on: accessoryID) },
                onFailure: {
                    // Roll back to the pre-tap target so the UI doesn't
                    // claim a setpoint the thermostat never accepted.
                    // We write into targetDraft rather than clearing it
                    // so the display doesn't briefly snap to the
                    // (possibly stale) accessory capability value.
                    targetDraft = previousTarget
                },
                // Haptic already fires on the tap/long-press — avoid a
                // second success tick.
                successHaptic: .none,
                toast: { toast = .error("Couldn't set target temperature") },
                errorDescription: "Thermostat setpoint"
            )
            // On success, clear the draft so targetTemp falls back to
            // reading from the provider. On failure the revert above
            // has already written the previous value into the draft.
            if targetDraft == newTarget {
                targetDraft = nil
            }
        }
    }
}

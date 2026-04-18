//
//  T3ThermostatView.swift
//  house connect
//
//  T3/Swiss thermostat — 168px temperature number with orange degree glyph,
//  tick scale with dot indicator, mode selector, conditions grid, schedule.
//  Matches Claude Design handoff T3Thermo component.
//

import SwiftUI

struct T3ThermostatView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var targetDraft: Int?
    @State private var selectedMode: HVACMode = .heat

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var currentTemp: Int {
        guard let c = accessory?.currentTemperature else { return 68 }
        return Int((c * 9.0 / 5.0 + 32.0).rounded())
    }

    private var targetTemp: Int {
        if let draft = targetDraft { return draft }
        guard let accessory,
              case .targetTemperature(let c) = accessory.capability(of: .targetTemperature) else { return 71 }
        return Int((c * 9.0 / 5.0 + 32.0).rounded())
    }

    private let range = (60, 90)

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    THeader(
                        backLabel: "Living Room",
                        rightLabel: "Heating",
                        showDot: true,
                        onBack: { dismiss() }
                    )

                    // Huge number
                    VStack(alignment: .leading, spacing: 0) {
                        TLabel(text: "Interior")

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

                        // Target + buttons
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                TLabel(text: "Target")
                                Text("\(targetTemp)°")
                                    .font(T3.inter(22, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                    .monospacedDigit()
                            }

                            Spacer()

                            HStack(spacing: 10) {
                                // Minus button — outlined circle
                                Button {
                                    adjustTarget(by: -1)
                                } label: {
                                    Circle()
                                        .stroke(T3.rule, lineWidth: 1)
                                        .fill(T3.panel)
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            Image(systemName: "minus")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(T3.ink)
                                        )
                                }
                                .buttonStyle(.plain)

                                // Plus button — orange filled circle
                                Button {
                                    adjustTarget(by: 1)
                                } label: {
                                    Circle()
                                        .fill(T3.accent)
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(.white)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 28)
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

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let mode = accessory?.hvacMode {
                selectedMode = mode
            }
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
                TLabel(text: "75°")
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
                        selectedMode = mode
                        Task {
                            try? await registry.execute(.setHVACMode(mode), on: accessoryID)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedMode == mode ? T3.page : T3.ink)
                            Text(label)
                                .font(.system(size: 11, weight: .medium))
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
        HStack(spacing: 18) {
            conditionCell(label: "Int Hum", value: "42%")
            conditionCell(label: "Out Temp", value: "51°")
            conditionCell(label: "Out Hum", value: "73%")
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

    // MARK: - Actions

    private func adjustTarget(by delta: Int) {
        let newTarget = targetTemp + delta
        guard newTarget >= range.0 && newTarget <= range.1 else { return }
        targetDraft = newTarget
        let celsius = Double(newTarget - 32) * 5.0 / 9.0
        Task {
            try? await registry.execute(.setTargetTemperature(celsius), on: accessoryID)
            targetDraft = nil
        }
    }
}

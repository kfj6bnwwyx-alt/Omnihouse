//
//  T3LightDetailView.swift
//  house connect
//
//  T3/Swiss light detail — 96px brightness percentage, tick scale,
//  color temperature segmented control, stats strip.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3LightDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isOn: Bool = true
    @State private var brightness: Double = 0.82
    @State private var colorTemp: String = "Warm"
    @State private var lastHapticBucket: Int = -1
    @State private var toast: Toast?
    // Captured at the start of a brightness drag so we can revert
    // the slider if the final committed value fails to apply.
    @State private var dragStartBrightness: Double = 0

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "Devices" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "Room"
    }

    /// Whether this light supports color temperature adjustment.
    private var supportsColorTemp: Bool {
        accessory?.capability(of: .colorTemperature) != nil
    }

    /// Named color temperature presets with their Kelvin values and
    /// the closest mired equivalent (used for `.setColorTemperature`).
    private static let colorTempPresets: [(name: String, kelvin: String, mireds: Int)] = [
        ("Warm",    "2700K", 370),
        ("Neutral", "3500K", 286),
        ("Cool",    "5000K", 200),
        ("Day",     "6500K", 154),
    ]

    /// Find the named preset closest to a given mired value.
    private static func nearestPreset(mireds: Int) -> String {
        colorTempPresets
            .min(by: { abs($0.mireds - mireds) < abs($1.mireds - mireds) })?
            .name ?? "Warm"
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: roomName, onBack: { dismiss() })

                    // Eyebrow + big number + toggle
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if isOn { TDot(size: 8).accessibilityHidden(true) }
                            TLabel(text: isOn ? "On" : "Off")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(accessory?.name ?? "Light"), \(isOn ? "on, \(Int(brightness * 100)) percent brightness" : "off")")

                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(brightness * 100))")
                                .font(T3.inter(96, weight: .light))
                                .tracking(-4)
                                .foregroundStyle(T3.ink)
                                .monospacedDigit()
                                .accessibilityHidden(true)

                            Text("%")
                                .font(T3.inter(36, weight: .light))
                                .foregroundStyle(isOn ? T3.accent : T3.sub)
                                .accessibilityHidden(true)

                            Spacer()

                            TPill(isOn: $isOn, size: CGSize(width: 48, height: 26))
                                .accessibilityLabel(isOn ? "Turn off" : "Turn on")
                                .accessibilityAddTraits(.isButton)
                                .onChange(of: isOn) { oldValue, newValue in
                                    // Snapshot the prior state so a revert
                                    // closure can put it back if the command
                                    // fails. Without this the pill would stay
                                    // lit after a silent provider error.
                                    let previous = oldValue
                                    Task { @MainActor in
                                        await T3ActionFeedback.perform(
                                            action: { try await registry.execute(.setPower(newValue), on: accessoryID) },
                                            onFailure: { isOn = previous },
                                            toast: { toast = .error("Couldn't reach \(accessory?.name ?? "light")") },
                                            errorDescription: "Light power"
                                        )
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 12)

                    // Brightness section
                    TSectionHead(title: "Brightness")

                    brightnessScale
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 12)

                    // Quick-pick row
                    HStack(spacing: 8) {
                        ForEach([25, 50, 75, 100], id: \.self) { pct in
                            Button {
                                let previousBrightness = brightness
                                let previousIsOn = isOn
                                brightness = Double(pct) / 100.0
                                isOn = true
                                let newBrightness = brightness
                                Task { @MainActor in
                                    await T3ActionFeedback.perform(
                                        action: { try await registry.execute(.setBrightness(newBrightness), on: accessoryID) },
                                        onFailure: {
                                            brightness = previousBrightness
                                            isOn = previousIsOn
                                        },
                                        toast: { toast = .error("Couldn't set brightness") },
                                        errorDescription: "Light quick-pick"
                                    )
                                }
                            } label: {
                                Text("\(pct)")
                                    .font(T3.mono(11))
                                    .tracking(0.5)
                                    .foregroundStyle(Int(brightness * 100) == pct ? T3.page : T3.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: T3.segmentCellRadius)
                                            .fill(Int(brightness * 100) == pct ? T3.ink : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Set brightness to \(pct) percent")
                            .accessibilityAddTraits(Int(brightness * 100) == pct ? [.isButton, .isSelected] : .isButton)
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

                    // Color Temperature — only shown when the accessory
                    // actually supports it. Tapping a preset sends the
                    // corresponding mired value to the provider.
                    if supportsColorTemp {
                        TRule()

                        TSectionHead(title: "Temperature")

                        HStack(spacing: 6) {
                            ForEach(T3LightDetailView.colorTempPresets, id: \.name) { preset in
                                Button {
                                    let previousColorTemp = colorTemp
                                    colorTemp = preset.name
                                    let mireds = preset.mireds
                                    Task { @MainActor in
                                        await T3ActionFeedback.perform(
                                            action: { try await registry.execute(.setColorTemperature(mireds), on: accessoryID) },
                                            onFailure: { colorTemp = previousColorTemp },
                                            toast: { toast = .error("Couldn't set color temperature") },
                                            errorDescription: "Light color temperature"
                                        )
                                    }
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(preset.name)
                                            .font(T3.inter(12, weight: .medium))
                                        Text(preset.kelvin)
                                            .font(T3.mono(9))
                                            .tracking(0.5)
                                    }
                                    .foregroundStyle(colorTemp == preset.name ? T3.page : T3.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: T3.segmentCellRadius)
                                            .fill(colorTemp == preset.name ? T3.ink : .clear)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(preset.name) color temperature, \(preset.kelvin)")
                                .accessibilityAddTraits(colorTemp == preset.name ? [.isButton, .isSelected] : .isButton)
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

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast, duration: 4)
        .onAppear {
            syncFromAccessory()
        }
        // Keep state in sync when HA pushes a live update while the view
        // is open (e.g., another person controls the light from the app
        // or a scene fires). Guard against overwriting in-progress drags
        // via `lastHapticBucket != -1`.
        .onChange(of: accessory?.isOn) { _, newOn in
            guard let newOn else { return }
            isOn = newOn
        }
        .onChange(of: accessory?.brightness) { _, newBrightness in
            guard let newBrightness, lastHapticBucket == -1 else { return }
            brightness = newBrightness
        }
        .onChange(of: accessory?.capability(of: .colorTemperature)) { _, newCap in
            if case .colorTemperature(let m) = newCap {
                colorTemp = T3LightDetailView.nearestPreset(mireds: m)
            }
        }
    }

    private func syncFromAccessory() {
        guard let acc = accessory else { return }
        isOn = acc.isOn ?? false
        brightness = acc.brightness ?? 0.82
        if case .colorTemperature(let m) = acc.capability(of: .colorTemperature) {
            colorTemp = T3LightDetailView.nearestPreset(mireds: m)
        }
    }

    // MARK: - Brightness Scale

    private var brightnessScale: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<41, id: \.self) { i in
                        let f = Double(i) / 40.0
                        let major = i % 5 == 0
                        let on = f <= brightness
                        Rectangle()
                            .fill(on ? T3.ink : T3.rule)
                            .frame(width: 1, height: major ? 14 : 7)
                            .position(x: f * geo.size.width, y: major ? 7 : 3.5)
                    }

                    TDot(size: 10)
                        .position(x: brightness * geo.size.width, y: 22)
                }
                .frame(width: geo.size.width, height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if lastHapticBucket == -1 {
                                // First tick of a fresh drag — capture the
                                // pre-drag brightness so we can roll back to
                                // it if the provider rejects the final value.
                                dragStartBrightness = brightness
                            }
                            let newVal = max(0, min(1, value.location.x / geo.size.width))
                            brightness = newVal
                            // Fire a light tick haptic each time the value
                            // crosses a whole-10%-bucket boundary during
                            // drag. onEnded intentionally does not re-fire.
                            let bucket = Int((newVal * 10).rounded(.down))
                            if bucket != lastHapticBucket {
                                lastHapticBucket = bucket
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                        }
                        .onEnded { _ in
                            let startValue = dragStartBrightness
                            let committedValue = brightness
                            lastHapticBucket = -1
                            Task { @MainActor in
                                await T3ActionFeedback.perform(
                                    action: { try await registry.execute(.setBrightness(committedValue), on: accessoryID) },
                                    onFailure: { brightness = startValue },
                                    // Drag already fires per-bucket ticks — an
                                    // extra .light on success would feel double.
                                    successHaptic: .none,
                                    toast: { toast = .error("Couldn't set brightness") },
                                    errorDescription: "Light brightness drag"
                                )
                            }
                        }
                )
            }
            .frame(height: 28)

            HStack {
                TLabel(text: "0")
                Spacer()
                TLabel(text: "50")
                Spacer()
                TLabel(text: "100")
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int(brightness * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            let previous = brightness
            switch direction {
            case .increment: brightness = min(1, brightness + step)
            case .decrement: brightness = max(0, brightness - step)
            @unknown default: break
            }
            let newVal = brightness
            Task { @MainActor in
                await T3ActionFeedback.perform(
                    action: { try await registry.execute(.setBrightness(newVal), on: accessoryID) },
                    onFailure: { brightness = previous },
                    successHaptic: .none,
                    toast: { toast = .error("Couldn't set brightness") },
                    errorDescription: "Light brightness a11y adjust"
                )
            }
        }
    }

}

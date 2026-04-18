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

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: accessory?.roomID != nil ? "Room" : "Devices", onBack: { dismiss() })

                    // Eyebrow + big number + toggle
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if isOn { TDot(size: 8) }
                            TLabel(text: isOn ? "On" : "Off")
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(brightness * 100))")
                                .font(T3.inter(96, weight: .light))
                                .tracking(-4)
                                .foregroundStyle(T3.ink)
                                .monospacedDigit()

                            Text("%")
                                .font(T3.inter(36, weight: .light))
                                .foregroundStyle(isOn ? T3.accent : T3.sub)

                            Spacer()

                            TPill(isOn: $isOn, size: CGSize(width: 48, height: 26))
                                .onChange(of: isOn) { _, v in
                                    Task { try? await registry.execute(.setPower(v), on: accessoryID) }
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
                                brightness = Double(pct) / 100.0
                                isOn = true
                                Task { try? await registry.execute(.setBrightness(brightness), on: accessoryID) }
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

                    TRule()

                    // Color Temperature
                    TSectionHead(title: "Temperature")

                    HStack(spacing: 6) {
                        ForEach([
                            ("Warm", "2700K"),
                            ("Neutral", "3500K"),
                            ("Cool", "5000K"),
                            ("Day", "6500K"),
                        ], id: \.0) { name, kelvin in
                            Button {
                                colorTemp = name
                            } label: {
                                VStack(spacing: 2) {
                                    Text(name)
                                        .font(T3.inter(12, weight: .medium))
                                    Text(kelvin)
                                        .font(T3.mono(9))
                                        .tracking(0.5)
                                }
                                .foregroundStyle(colorTemp == name ? T3.page : T3.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: T3.segmentCellRadius)
                                        .fill(colorTemp == name ? T3.ink : .clear)
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

                    TRule()

                    // Stats strip
                    HStack(spacing: 18) {
                        statCell(label: "Power", value: "9W")
                        statCell(label: "Uptime", value: "4h 12m")
                        statCell(label: "Since", value: "Morning")
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let acc = accessory {
                isOn = acc.isOn ?? false
                brightness = acc.brightness ?? 0.82
            }
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
                            Task { try? await registry.execute(.setBrightness(brightness), on: accessoryID) }
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
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

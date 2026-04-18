//
//  T3RoomDetailView.swift
//  house connect
//
//  T3/Swiss room detail — indexed device list with pill toggles.
//  Back → Rooms, device rows navigate to type-specific detail.
//

import SwiftUI

struct T3RoomDetailView: View {
    let roomID: String
    let providerID: ProviderID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    private var room: Room? {
        registry.allRooms.first { $0.id == roomID && $0.provider == providerID }
    }

    private var devices: [Accessory] {
        registry.allAccessories
            .filter { $0.roomID == roomID && $0.id.provider == providerID }
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
                    // Header
                    THeader(
                        backLabel: "Rooms",
                        rightLabel: "Room \(String(format: "%02d", roomIndex + 1))",
                        onBack: { dismiss() }
                    )

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
                            .padding(.top, 8)

                        Text("\(activeCount) of \(devices.count) devices on · \(providers.joined(separator: " + "))")
                            .font(.system(size: 13))
                            .foregroundStyle(T3.sub)
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                    TRule()

                    // Devices section
                    TSectionHead(title: "Devices", count: String(format: "%02d", devices.count))

                    ForEach(Array(devices.enumerated()), id: \.element.id) { i, device in
                        T3DeviceRow(device: device, index: i, isLast: i == devices.count - 1)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

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

            Image(systemName: categoryIcon(device.category))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(T3.ink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(T3.inter(15, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)

                HStack(spacing: 8) {
                    if device.isOn == true { TDot(size: 5) }
                    Text(stateText(device))
                        .font(.system(size: 11))
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
        case .smokeAlarm: "smoke.fill"
        case .other: "questionmark.app"
        }
    }
}

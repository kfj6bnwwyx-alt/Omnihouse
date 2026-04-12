//
//  TopologyNodeDetailSheet.swift
//  house connect
//
//  Pencil `I2kbG` — Bottom sheet showing device info when tapping a
//  node on the topology map. Presented as `.sheet` from the topology
//  view. All network info is placeholder/simulated since we don't have
//  real network topology data yet.
//

import SwiftUI

struct TopologyNodeDetailSheet: View {
    let accessory: Accessory

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.space.sectionGap) {
                    topologyPreview
                    deviceHeader
                    deviceInfoCard
                    connectedDevicesSection
                    actionButtons
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 20)
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Topology Preview

    /// Simplified mini-preview: purple hub circle with the selected node
    /// highlighted, matching the sheet design in the Pencil comp.
    private var topologyPreview: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Theme.color.primary.opacity(0.10), lineWidth: 1)
                .frame(width: 120, height: 120)

            // Line from hub to node
            Path { path in
                path.move(to: CGPoint(x: 80, y: 80))
                path.addLine(to: CGPoint(x: 130, y: 40))
            }
            .stroke(Theme.color.primary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Central hub
            Circle()
                .fill(Theme.color.primary)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "house.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )

            // Selected node — positioned top-right
            Circle()
                .fill(Theme.color.primary)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: iconName(for: accessory.category))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Theme.color.primary.opacity(0.3),
                        radius: 8, x: 0, y: 4)
                .offset(x: 50, y: -40)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .hcCard()
    }

    // MARK: - Device Header

    private var deviceHeader: some View {
        HStack(spacing: 12) {
            IconChip(
                systemName: iconName(for: accessory.category),
                size: 36,
                fill: Theme.color.primary.opacity(0.15),
                glyph: Theme.color.primary
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.color.title)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.color.success)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.color.success)
                }
            }

            Spacer()
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Info")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                infoRow(label: "Protocol", value: "Thread")
                Divider().foregroundStyle(Theme.color.divider)
                infoRow(label: "IP Address", value: "192.168.1.42")
                Divider().foregroundStyle(Theme.color.divider)
                infoRow(label: "Signal Strength", icon: "wifi", value: nil)
                Divider().foregroundStyle(Theme.color.divider)
                infoRow(label: "Firmware", value: "v2.4.1")
            }
            .hcCard()
        }
    }

    private func infoRow(label: String, icon: String? = nil, value: String?) -> some View {
        HStack {
            Text(label)
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
            Spacer()
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.success)
            }
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.color.title)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Connected Devices

    private var connectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Devices")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 8) {
                connectedDeviceRow(icon: "hifispeaker.fill",
                                   name: "Living Room Speaker",
                                   signal: "Excellent",
                                   signalColor: Theme.color.success)
                connectedDeviceRow(icon: "lightbulb.fill",
                                   name: "Kitchen Light",
                                   signal: "Good",
                                   signalColor: Theme.color.primary)
                connectedDeviceRow(icon: "lock.fill",
                                   name: "Front Door Lock",
                                   signal: "Fair",
                                   signalColor: Color.orange)
            }
            .hcCard()
        }
    }

    private func connectedDeviceRow(icon: String, name: String,
                                     signal: String, signalColor: Color) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon, size: 32)
            Text(name)
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
            Spacer()
            Text("Signal: \(signal)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(signalColor)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Ping — accent fill
            Button {
                // placeholder
            } label: {
                Label("Ping", systemImage: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                            .fill(Theme.color.primary)
                    )
            }
            .buttonStyle(.plain)

            // Restart — accent outline
            Button {
                // placeholder
            } label: {
                Text("Restart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                            .stroke(Theme.color.primary, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            // Remove — danger outline
            Button {
                // placeholder
            } label: {
                Text("Remove")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                            .stroke(Theme.color.danger, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func iconName(for category: Accessory.Category) -> String {
        switch category {
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
        case .other: "questionmark.app.fill"
        }
    }
}

//
//  TopologyStatusViews.swift
//  house connect
//
//  Five status/result screens that appear after topology actions.
//  Bundled in one file since they're simple status pages with
//  placeholder data.
//
//  Pencil refs:
//    5a — TopologyDeviceAddedView       `WMPrn`
//    5b — TopologyNetworkOptimizedView   `nSgaN`
//    5c — TopologyAllOnlineView          `jMwkI`
//    5d — TopologyDeviceLostView         `w37nK`
//    5e — TopologyHubUnreachableView     `oKWze`
//

import SwiftUI

// MARK: - 5a: Device Added

struct TopologyDeviceAddedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                    backHeader(title: "Device Network")
                    successBanner
                    deviceDetailsCard
                    actionButtons
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Extracted sections

    private var successBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.success.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.color.success)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Thermostat Added")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                Text("Connected via Thread · Signal: Strong")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.subtitle)
                Text("Just now")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.color.muted)
            }
            Spacer()
        }
        .hcCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .stroke(Theme.color.success.opacity(0.25), lineWidth: 1)
        )
    }

    private var deviceDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                labeledRow("Protocol", value: "Thread")
                Divider().foregroundStyle(Theme.color.divider)
                labeledRow("Room", value: "Living Room")
                Divider().foregroundStyle(Theme.color.divider)
                labeledRow("Signal Strength", value: "Strong")
                Divider().foregroundStyle(Theme.color.divider)
                labeledRow("IP Address", value: "192.168.1.87")
                Divider().foregroundStyle(Theme.color.divider)
                labeledRow("Firmware", value: "v3.1.0")
            }
            .hcCard()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                // placeholder
            } label: {
                Text("Configure Device")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                            .fill(Theme.color.primary)
                    )
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.color.subtitle)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 5b: Network Optimized

struct TopologyNetworkOptimizedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.space.sectionGap) {
                    backHeader(title: "Network Diagnostics")
                    successIcon
                    titleMessage
                    improvementsTable
                    changesAppliedCard
                    doneButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Extracted sections

    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.color.success.opacity(0.12))
                .frame(width: 96, height: 96)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.color.success)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var titleMessage: some View {
        VStack(spacing: 6) {
            Text("Network Optimized")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.color.title)
            Text("Your network has been analyzed and optimized for the best performance.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var improvementsTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Improvements")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                HStack {
                    Text("Metric")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Before")
                        .frame(width: 70, alignment: .center)
                    Text("After")
                        .frame(width: 70, alignment: .center)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
                .padding(.bottom, 8)

                Divider().foregroundStyle(Theme.color.divider)

                improvementRow(metric: "Avg Latency", before: "45ms", after: "8ms")
                Divider().foregroundStyle(Theme.color.divider)
                improvementRow(metric: "Signal Quality", before: "Fair", after: "Strong")
                Divider().foregroundStyle(Theme.color.divider)
                improvementRow(metric: "Dead Zones", before: "2", after: "0")
            }
            .hcCard()
        }
    }

    private var changesAppliedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes Applied")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 8) {
                changeRow("Rerouted Thread mesh through bedroom hub")
                changeRow("Updated channel allocation for 5 GHz band")
                changeRow("Enabled power-save on 3 idle devices")
            }
            .hcCard()
        }
    }

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                        .fill(Theme.color.primary)
                )
        }
        .buttonStyle(.plain)
    }

    private func improvementRow(metric: String, before: String, after: String) -> some View {
        HStack {
            Text(metric)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.color.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(before)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.danger)
                .frame(width: 70, alignment: .center)
            Text(after)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color.success)
                .frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 8)
    }

    private func changeRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.color.success)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.title)
            Spacer()
        }
    }
}

// MARK: - 5c: All Online

struct TopologyAllOnlineView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                    screenHeader
                    statusPill
                    networkHealthCard
                    connectedDevicesCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Extracted sections

    private var screenHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Device Network")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)
            Spacer()
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.color.success)
                .frame(width: 8, height: 8)
            Text("All 14 Devices Online")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.success)
            Text("·")
                .foregroundStyle(Theme.color.muted)
            Text("Just now")
                .font(.system(size: 12))
                .foregroundStyle(Theme.color.muted)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Theme.color.success.opacity(0.10))
        )
    }

    private var networkHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Health")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                healthRow(label: "Uptime", value: "99.9%")
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(label: "Avg Latency", value: "6ms")
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(label: "Signal Quality", value: "Excellent")
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(label: "Dead Zones", value: "None")
            }
            .hcCard()
        }
    }

    private var connectedDevicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Devices")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 8) {
                deviceRow(icon: "thermometer.medium",
                          name: "Smart Thermostat",
                          protocol: "Thread")
                deviceRow(icon: "hifispeaker.fill",
                          name: "Living Room Speaker",
                          protocol: "Wi-Fi")
                deviceRow(icon: "lock.fill",
                          name: "Front Door Lock",
                          protocol: "Zigbee")
            }
            .hcCard()
        }
    }

    private func healthRow(label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.color.success)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.subtitle)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color.title)
        }
        .padding(.vertical, 8)
    }

    private func deviceRow(icon: String, name: String, protocol proto: String) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon, size: 32)
            Text(name)
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
            Spacer()
            Text(proto)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Theme.color.primary.opacity(0.10))
                )
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 5d: Device Lost

struct TopologyDeviceLostView: View {
    @Environment(\.dismiss) private var dismiss

    private let warningColor = Color.orange

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                    screenHeader
                    warningBanner
                    deviceInfoCard
                    troubleshootingCard
                    reconnectButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Extracted sections

    private var screenHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Device Network")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)
            Spacer()
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
    }

    private var warningBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(warningColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(warningColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Bedroom Camera Offline")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                Text("Lost connection 3 min ago · Last signal: Weak")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
        }
        .hcCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .stroke(warningColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Info")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                labeledRow("Device", value: "Bedroom Camera")
                Divider().foregroundStyle(Theme.color.divider)
                labeledRow("Protocol", value: "Wi-Fi")
                Divider().foregroundStyle(Theme.color.divider)
                HStack {
                    Text("Last Signal")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                    Spacer()
                    Text("-72 dBm")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.color.danger)
                }
                .padding(.vertical, 10)
                Divider().foregroundStyle(Theme.color.divider)
                labeledRow("Last Online", value: "3 min ago")
            }
            .hcCard()
        }
    }

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Troubleshooting")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                troubleshootRow("Check device power")
                Divider().foregroundStyle(Theme.color.divider)
                troubleshootRow("Move closer to hub")
                Divider().foregroundStyle(Theme.color.divider)
                troubleshootRow("Restart device remotely")
            }
            .hcCard()
        }
    }

    private var reconnectButton: some View {
        Button {
            // placeholder
        } label: {
            Text("Try Reconnecting")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                        .fill(Theme.color.danger)
                )
        }
        .buttonStyle(.plain)
    }

    private func troubleshootRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 14))
                .foregroundStyle(Theme.color.primary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.muted)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - 5e: Hub Unreachable

struct TopologyHubUnreachableView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.space.sectionGap) {
                    backHeader(title: "Device Network")
                    errorIcon
                    errorMessage
                    troubleshootingSteps
                    actionButtons
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Extracted sections

    private var errorIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.color.danger.opacity(0.10))
                .frame(width: 96, height: 96)
            Image(systemName: "wifi.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.color.danger)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var errorMessage: some View {
        VStack(spacing: 6) {
            Text("Hub Unreachable")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.color.danger)
            Text("Unable to communicate with your home hub. Your devices may not respond until the connection is restored.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Text("Last connected: 12 min ago")
                .font(.system(size: 12))
                .foregroundStyle(Theme.color.muted)
        }
    }

    private var troubleshootingSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try These Steps")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 10) {
                stepRow(number: 1, text: "Check hub power cable")
                stepRow(number: 2, text: "Restart your router")
                stepRow(number: 3, text: "Power cycle the hub (30 sec)")
                stepRow(number: 4, text: "Contact support")
            }
            .hcCard()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                // placeholder
            } label: {
                Text("Retry Connection")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                            .fill(Theme.color.danger)
                    )
            }
            .buttonStyle(.plain)

            Button {
                // placeholder
            } label: {
                Text("Contact Support")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.color.subtitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.pill, style: .continuous)
                            .stroke(Theme.color.divider, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.danger.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.color.danger)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.title)
            Spacer()
        }
    }
}

// MARK: - Shared Helpers

/// Reusable back header used by several topology status views.
private func backHeader(title: String) -> some View {
    TopologyStatusBackHeader(title: title)
}

/// Reusable labeled row for device info cards.
private func labeledRow(_ label: String, value: String) -> some View {
    TopologyStatusLabeledRow(label: label, value: value)
}

// Internal view so the free functions above can reference concrete types.
private struct TopologyStatusBackHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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

            Text(title)
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)

            Spacer()
        }
    }
}

private struct TopologyStatusLabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.color.title)
        }
        .padding(.vertical, 10)
    }
}

//
//  TopologyStatusViews.swift
//  house connect
//
//  Five status/result screens that appear after topology actions.
//  Converted to the T3/Swiss design system (hairline rules, T3 tokens,
//  no rounded cards, Lucide glyphs). Placeholder data preserved as-is —
//  the screens have no real network-probe backend yet.
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
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(
                        title: "Device added.",
                        subtitle: "SMART THERMOSTAT · THREAD"
                    )

                    // Status row
                    TSectionHead(title: "Status")
                    statusRow(
                        icon: "checkmark.circle.fill",
                        color: T3.ok,
                        title: "Smart Thermostat Added",
                        sub: "Connected via Thread · Signal: Strong · Just now"
                    )

                    // Device details
                    TSectionHead(title: "Device details")
                    detailRow(label: "Protocol",        value: "Thread")
                    detailRow(label: "Room",             value: "Living Room")
                    detailRow(label: "Signal Strength",  value: "Strong")
                    detailRow(label: "IP Address",       value: "192.168.1.87")
                    detailRow(label: "Firmware",         value: "v3.1.0", isLast: true)

                    actionButton(title: "CONFIGURE DEVICE", style: .primary) {}
                    secondaryButton(title: "Done") { dismiss() }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - 5b: Network Optimized

struct TopologyNetworkOptimizedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Network Diagnostics", onBack: { dismiss() })

                    TTitle(
                        title: "Network optimized.",
                        subtitle: "Analyzed + tuned for best performance"
                    )

                    // Improvements table
                    TSectionHead(title: "Improvements", count: "03")
                    improvementRow(metric: "Avg Latency",     before: "45ms", after: "8ms")
                    improvementRow(metric: "Signal Quality",  before: "Fair", after: "Strong")
                    improvementRow(metric: "Dead Zones",      before: "2",    after: "0",
                                   isLast: true)

                    // Changes applied
                    TSectionHead(title: "Changes applied", count: "03")
                    changeRow("Rerouted Thread mesh through bedroom hub")
                    changeRow("Updated channel allocation for 5 GHz band")
                    changeRow("Enabled power-save on 3 idle devices", isLast: true)

                    actionButton(title: "DONE", style: .primary) { dismiss() }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func improvementRow(
        metric: String, before: String, after: String,
        isLast: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            TLabel(text: metric.uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(before)
                .font(T3.mono(11))
                .foregroundStyle(T3.danger)
                .frame(width: 60, alignment: .trailing)
            T3IconImage(systemName: "arrow.right")
                .frame(width: 10, height: 10)
                .foregroundStyle(T3.sub)
                .padding(.horizontal, 4)
            Text(after)
                .font(T3.mono(11))
                .foregroundStyle(T3.ok)
                .frame(width: 60, alignment: .leading)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func changeRow(_ text: String, isLast: Bool = false) -> some View {
        HStack(spacing: 10) {
            T3IconImage(systemName: "checkmark")
                .frame(width: 12, height: 12)
                .foregroundStyle(T3.ok)
                .accessibilityHidden(true)
            Text(text)
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.ink)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

// MARK: - 5c: All Online

struct TopologyAllOnlineView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(
                        title: "All online.",
                        subtitle: "14 DEVICES · CHECKED JUST NOW",
                        isActive: true
                    )

                    // Network health
                    TSectionHead(title: "Network health", count: "04")
                    detailRow(label: "Uptime",          value: "99.9%")
                    detailRow(label: "Avg Latency",     value: "6 ms")
                    detailRow(label: "Signal Quality",  value: "Excellent")
                    detailRow(label: "Dead Zones",      value: "None", isLast: true)

                    // Connected devices (sample)
                    TSectionHead(title: "Connected devices", count: "03")
                    connectedDeviceRow(
                        icon: "thermometer",
                        name: "Smart Thermostat",
                        proto: "Thread"
                    )
                    connectedDeviceRow(
                        icon: "hifispeaker",
                        name: "Living Room Speaker",
                        proto: "Wi-Fi"
                    )
                    connectedDeviceRow(
                        icon: "lock",
                        name: "Front Door Lock",
                        proto: "Zigbee",
                        isLast: true
                    )

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func connectedDeviceRow(
        icon: String, name: String, proto: String, isLast: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: icon)
                .frame(width: 18, height: 18)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            Text(name)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            TLabel(text: proto.uppercased())
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

// MARK: - 5d: Device Lost

struct TopologyDeviceLostView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(
                        title: "Device offline.",
                        subtitle: "BEDROOM CAMERA · LOST 3 MIN AGO"
                    )

                    // Warning banner
                    TSectionHead(title: "Status")
                    statusRow(
                        icon: "exclamationmark.triangle",
                        color: T3.danger,
                        title: "Bedroom Camera Offline",
                        sub: "Lost connection 3 min ago · Last signal: Weak"
                    )

                    // Device info
                    TSectionHead(title: "Device info")
                    detailRow(label: "Device",      value: "Bedroom Camera")
                    detailRow(label: "Protocol",    value: "Wi-Fi")
                    detailRow(label: "Last Signal", value: "−72 dBm", valueColor: T3.danger)
                    detailRow(label: "Last Online", value: "3 min ago", isLast: true)

                    // Troubleshooting
                    TSectionHead(title: "Troubleshooting", count: "03")
                    troubleshootRow("Check device power")
                    troubleshootRow("Move closer to hub")
                    troubleshootRow("Restart device remotely", isLast: true)

                    actionButton(title: "TRY RECONNECTING", style: .danger) {}
                    secondaryButton(title: "Back") { dismiss() }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func troubleshootRow(_ text: String, isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: "sparkle")
                .frame(width: 14, height: 14)
                .foregroundStyle(T3.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            T3IconImage(systemName: "chevron.right")
                .frame(width: 10, height: 10)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

// MARK: - 5e: Hub Unreachable

struct TopologyHubUnreachableView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(
                        title: "Hub unreachable.",
                        subtitle: "LAST CONNECTED 12 MIN AGO"
                    )

                    // Status
                    TSectionHead(title: "Status")
                    statusRow(
                        icon: "wifi.slash",
                        color: T3.danger,
                        title: "Hub Unreachable",
                        sub: "Unable to communicate with your home hub. Devices may not respond until the connection is restored."
                    )

                    // Steps to resolve
                    TSectionHead(title: "Try these steps", count: "04")
                    stepRow(number: 1, text: "Check hub power cable")
                    stepRow(number: 2, text: "Restart your router")
                    stepRow(number: 3, text: "Power cycle the hub (30 sec)")
                    stepRow(number: 4, text: "Contact support", isLast: true)

                    actionButton(title: "RETRY CONNECTION", style: .danger) {}
                    secondaryButton(title: "Contact Support") {}

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func stepRow(number: Int, text: String, isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(T3.mono(11))
                .foregroundStyle(T3.page)
                .frame(width: 22, height: 22)
                .background(T3.danger)
                .accessibilityHidden(true)
            Text(text)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

// MARK: - Shared helpers (file-private)

/// Status banner row: icon + title + subtitle.
private func statusRow(
    icon: String,
    color: Color,
    title: String,
    sub: String
) -> some View {
    TopologyStatusRow(icon: icon, color: color, title: title, sub: sub)
}

private struct TopologyStatusRow: View {
    let icon: String
    let color: Color
    let title: String
    let sub: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(color)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    T3IconImage(systemName: icon)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                }
                Text(sub)
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }
}

/// Key-value detail row.
private func detailRow(
    label: String,
    value: String,
    valueColor: Color = T3.ink,
    isLast: Bool = false
) -> some View {
    TopologyDetailRow(label: label, value: value, valueColor: valueColor, isLast: isLast)
}

private struct TopologyDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = T3.ink
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            TLabel(text: label.uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(T3.mono(12))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

// MARK: - Button helpers

private enum ButtonStyle_ { case primary, danger }

private func actionButton(
    title: String,
    style: ButtonStyle_,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Text(title)
            .font(T3.mono(12))
            .tracking(2)
            .foregroundStyle(T3.page)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(style == .danger ? T3.danger : T3.ink)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, T3.screenPadding)
    .padding(.top, 24)
}

private func secondaryButton(
    title: String,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Text(title)
            .font(T3.mono(11))
            .tracking(1)
            .foregroundStyle(T3.sub)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, T3.screenPadding)
    .padding(.top, 10)
}

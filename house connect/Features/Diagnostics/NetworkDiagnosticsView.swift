//
//  NetworkDiagnosticsView.swift
//  house connect
//
//  Pencil `zo6mD` — Network health diagnostics screen. All values are
//  placeholder/simulated — no real network probes yet. The "Run Full Scan"
//  button triggers a fake loading state to demonstrate the interaction.
//

import SwiftUI

struct NetworkDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Simulated state

    @State private var isScanning = false
    @State private var lastScan = "2 min ago"
    @State private var avgLatency = "8ms"
    @State private var uptime = "99.8%"
    @State private var devicesOnline = "14 / 16"
    @State private var signalStrength = "-38 dBm"

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusCard
                    metricsGrid
                    healthChecksSection
                    scanButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
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

            Text("Network Diagnostics")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.color.title)

            Spacer()
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.33, green: 0.77, blue: 0.49).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.33, green: 0.77, blue: 0.49))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Network Healthy")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                Text("All systems operating normally")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.color.subtitle)
                Text("Last scan: \(lastScan)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.color.muted)
            }

            Spacer()
        }
        .padding(Theme.space.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Color(red: 0.33, green: 0.77, blue: 0.49).opacity(0.06))
                .shadow(color: Color.black.opacity(0.06),
                        radius: 10, x: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Network Healthy. All systems operating normally. Last scan: \(lastScan)")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Metrics grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Network Metrics")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                metricCard(value: avgLatency, label: "Avg Latency", icon: "waveform.path.ecg")
                metricCard(value: uptime, label: "Uptime", icon: "arrow.up.circle")
                metricCard(value: devicesOnline, label: "Devices Online", icon: "wifi")
                metricCard(value: signalStrength, label: "Signal Strength", icon: "antenna.radiowaves.left.and.right")
            }
        }
    }

    private func metricCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.color.primary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.color.title)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Health checks

    private var healthChecksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Health Checks")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                healthRow(
                    dot: Color(red: 0.33, green: 0.77, blue: 0.49),
                    title: "Hub reachable",
                    detail: "< 1ms"
                )
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(
                    dot: Color(red: 0.33, green: 0.77, blue: 0.49),
                    title: "Thread mesh stable",
                    detail: "12 nodes"
                )
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(
                    dot: Color(red: 0.33, green: 0.77, blue: 0.49),
                    title: "Wi-Fi gateway online",
                    detail: "Strong"
                )
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(
                    dot: Color(red: 0.95, green: 0.75, blue: 0.20),
                    title: "Zigbee bridge",
                    detail: "Slow"
                )
                Divider().foregroundStyle(Theme.color.divider)
                healthRow(
                    dot: Theme.color.danger,
                    title: "Outdoor camera",
                    detail: "Offline"
                )
            }
            .hcCard()
        }
    }

    private func healthRow(dot: Color, title: String, detail: String) -> some View {
        let statusText = healthStatusText(for: dot)
        return HStack(spacing: 12) {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.title)

            Spacer()

            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.color.muted)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(detail), \(statusText)")
    }

    private func healthStatusText(for color: Color) -> String {
        if color == Theme.color.danger { return "Error" }
        if color == Color(red: 0.95, green: 0.75, blue: 0.20) { return "Warning" }
        return "OK"
    }

    // MARK: - Scan button

    private var scanButton: some View {
        Button {
            runScan()
        } label: {
            HStack(spacing: 8) {
                if isScanning {
                    ProgressView()
                        .tint(.white)
                }
                Text(isScanning ? "Scanning..." : "Run Full Scan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(isScanning ? Theme.color.primary.opacity(0.7) : Theme.color.primary)
            )
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
        .accessibilityLabel(isScanning ? "Scanning network" : "Run Full Scan")
        .accessibilityHint(isScanning ? "Scan in progress" : "Runs a full network diagnostic scan")
    }

    // MARK: - Simulated scan

    private func runScan() {
        isScanning = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                lastScan = "Just now"
                isScanning = false
            }
        }
    }
}

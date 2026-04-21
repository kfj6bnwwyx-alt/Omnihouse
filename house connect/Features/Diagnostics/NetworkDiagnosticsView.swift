//
//  NetworkDiagnosticsView.swift
//  house connect
//
//  Pencil `zo6mD` — Network health diagnostics screen. All values are
//  placeholder/simulated — no real network probes yet. "Run Full Scan"
//  triggers a fake loading state. Converted to T3/Swiss design system:
//  TRule hairlines, T3 tokens, no rounded cards.
//

import SwiftUI

struct NetworkDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Simulated state

    @State private var isScanning     = false
    @State private var lastScan       = "2 min ago"
    @State private var avgLatency     = "8 ms"
    @State private var uptime         = "99.8%"
    @State private var devicesOnline  = "14 / 16"
    @State private var signalStrength = "−38 dBm"

    // MARK: - Static health checks

    private struct HealthCheck {
        let title:  String
        let detail: String
        let status: Status

        enum Status { case ok, warning, error }

        var dotColor: Color {
            switch status {
            case .ok:      T3.ok
            case .warning: T3.accent
            case .error:   T3.danger
            }
        }
        var accessibilityStatus: String {
            switch status {
            case .ok:      "OK"
            case .warning: "Warning"
            case .error:   "Error"
            }
        }
    }

    private let healthChecks: [HealthCheck] = [
        .init(title: "Hub reachable",        detail: "< 1 ms",   status: .ok),
        .init(title: "Thread mesh stable",   detail: "12 nodes", status: .ok),
        .init(title: "Wi-Fi gateway online", detail: "Strong",   status: .ok),
        .init(title: "Zigbee bridge",        detail: "Slow",     status: .warning),
        .init(title: "Outdoor camera",       detail: "Offline",  status: .error),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Device Network", onBack: { dismiss() })

                    TTitle(
                        title: "Diagnostics.",
                        subtitle: "LAST SCAN: \(lastScan.uppercased())"
                    )

                    // Status banner
                    TSectionHead(title: "Status")
                    statusBanner

                    // Metrics
                    TSectionHead(title: "Network metrics", count: "04")
                    metricRow(label: "Avg Latency",     value: avgLatency)
                    metricRow(label: "Uptime",          value: uptime)
                    metricRow(label: "Devices Online",  value: devicesOnline)
                    metricRow(label: "Signal Strength", value: signalStrength, isLast: true)

                    // Health checks
                    TSectionHead(title: "Health checks",
                                 count: "\(healthChecks.count)")
                    ForEach(Array(healthChecks.enumerated()), id: \.offset) { i, check in
                        healthRow(check, isLast: i == healthChecks.count - 1)
                    }

                    // Scan button
                    Button {
                        runScan()
                    } label: {
                        HStack(spacing: 10) {
                            if isScanning {
                                ProgressView()
                                    .tint(T3.page)
                                    .scaleEffect(0.8)
                                    .accessibilityHidden(true)
                            }
                            Text(isScanning ? "SCANNING…" : "RUN FULL SCAN")
                                .font(T3.mono(12))
                                .tracking(2)
                                .foregroundStyle(T3.page)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isScanning ? T3.sub : T3.ink)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 24)
                    .disabled(isScanning)
                    .accessibilityLabel(isScanning ? "Scanning network" : "Run full scan")
                    .accessibilityHint(isScanning ? "Scan in progress" : "Runs a full network diagnostic scan")

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(T3.ok)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    T3IconImage(systemName: "checkmark.circle.fill")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.ok)
                        .accessibilityHidden(true)
                    Text("Network Healthy")
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                }
                Text("All systems operating normally")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Network Healthy. All systems operating normally.")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Metric row

    private func metricRow(
        label: String,
        value: String,
        isLast: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            TLabel(text: label.uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(T3.mono(12))
                .foregroundStyle(T3.ink)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Health check row

    private func healthRow(_ check: HealthCheck, isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            TDot(size: 8, color: check.dotColor)
                .accessibilityHidden(true)
            Text(check.title)
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            Text(check.detail)
                .font(T3.mono(11))
                .foregroundStyle(check.status == .ok ? T3.sub : check.dotColor)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.title): \(check.detail), \(check.accessibilityStatus)")
    }

    // MARK: - Simulated scan

    private func runScan() {
        isScanning = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                lastScan = "just now"
                isScanning = false
            }
        }
    }
}

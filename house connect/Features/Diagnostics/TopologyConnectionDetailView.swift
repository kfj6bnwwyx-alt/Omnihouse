//
//  TopologyConnectionDetailView.swift
//  house connect
//
//  Pencil `rcXFH` — Pushed view showing details about a connection
//  between two devices/rooms. All metric values are placeholder since
//  we don't have real network topology data yet.
//

import SwiftUI

struct TopologyConnectionDetailView: View {
    let sourceName: String
    let destName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                    header
                    statusBanner
                    visualLink
                    metricsGrid
                    sharedContentSection
                    connectionHistorySection
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

            Text("\(sourceName) ↔ \(destName)")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)
                .lineLimit(1)

            Spacer()
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.color.success)

            Text("Connection Active")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            Spacer()

            Text("Active")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.color.success.opacity(0.12))
                )
        }
        .hcCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .stroke(Theme.color.success.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Visual Link

    private var visualLink: some View {
        HStack(spacing: 0) {
            // Source device
            VStack(spacing: 6) {
                IconChip(systemName: "hifispeaker.fill", size: 48,
                         fill: Theme.color.primary.opacity(0.15),
                         glyph: Theme.color.primary)
                Text(sourceName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            // Connecting line with label
            VStack(spacing: 4) {
                Text("Strong")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.color.success)

                Rectangle()
                    .fill(Theme.color.primary.opacity(0.4))
                    .frame(height: 2)
                    .frame(maxWidth: 80)
                    .overlay(
                        Circle()
                            .fill(Theme.color.primary)
                            .frame(width: 8, height: 8),
                        alignment: .center
                    )
            }
            .frame(maxWidth: .infinity)

            // Dest device
            VStack(spacing: 6) {
                IconChip(systemName: "lightbulb.fill", size: 48,
                         fill: Theme.color.primary.opacity(0.15),
                         glyph: Theme.color.primary)
                Text(destName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .hcCard()
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: Theme.space.cardGap) {
            HStack(spacing: Theme.space.cardGap) {
                metricCard(icon: "timer", label: "Latency", value: "12ms")
                metricCard(icon: "wifi", label: "Signal Strength",
                           value: "Strong", detail: "-42 dBm")
            }
            HStack(spacing: Theme.space.cardGap) {
                metricCard(icon: "clock.fill", label: "Uptime", value: "14d 6h")
                metricCard(icon: "antenna.radiowaves.left.and.right",
                           label: "Protocol", value: "Thread")
            }
        }
    }

    private func metricCard(icon: String, label: String,
                             value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.color.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.color.subtitle)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.color.title)

            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    // MARK: - Shared Content

    private var sharedContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Content")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            HStack(spacing: 14) {
                // Album art placeholder
                RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.color.primary, Theme.color.primary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Now Playing")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.color.muted)
                    Text("Midnight City")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.color.title)
                    Text("M83 — Hurry Up, We're Dreaming")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.color.subtitle)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
            )
        }
    }

    // MARK: - Connection History

    private var connectionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection History")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)

            VStack(spacing: 0) {
                historyRow(icon: "checkmark.circle.fill",
                           iconColor: Theme.color.success,
                           title: "Devices connected",
                           time: "Today, 8:42 AM")

                Divider().foregroundStyle(Theme.color.divider)

                historyRow(icon: "exclamationmark.triangle.fill",
                           iconColor: Color.orange,
                           title: "Connection lost",
                           time: "Yesterday, 11:15 PM")

                Divider().foregroundStyle(Theme.color.divider)

                historyRow(icon: "checkmark.circle.fill",
                           iconColor: Theme.color.success,
                           title: "Connection restored",
                           time: "Yesterday, 11:18 PM")

                Divider().foregroundStyle(Theme.color.divider)

                historyRow(icon: "arrow.triangle.2.circlepath",
                           iconColor: Theme.color.primary,
                           title: "Firmware updated",
                           time: "Apr 8, 2:30 PM")
            }
            .hcCard()
        }
    }

    private func historyRow(icon: String, iconColor: Color,
                             title: String, time: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.color.title)
                Text(time)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.color.muted)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

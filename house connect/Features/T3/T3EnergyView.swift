//
//  T3EnergyView.swift
//  house connect
//
//  T3/Swiss Energy dashboard — daily kWh, hourly bar chart,
//  by-category breakdown.
//
//  Data source: `EnergyService` (Core/Providers/EnergyService.swift).
//  The service fetches real Home Assistant `recorder/statistics_during_period`
//  data when a provider is connected; falls back to deterministic mock data
//  on failure. The view renders em-dashes while values are nil.
//

import SwiftUI

struct T3EnergyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EnergyService.self) private var energy

    /// Hourly fallback curve used when the service hasn't loaded yet,
    /// so the chart still has proportions to lay out. The bars render
    /// tinted at 20% opacity while data is nil so it's obviously not
    /// live yet.
    private static let hourlyFallback: [Double] =
        [0.4,0.3,0.3,0.3,0.3,0.4,0.9,1.2,0.8,0.6,0.5,0.5,
         0.7,0.6,0.5,0.6,0.9,1.3,1.4,1.2,0.9,0.7,0.5,0.4]

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Home", onBack: { dismiss() })

                    // Error banner — surfaces when EnergyService fell back
                    // to mock data. Without this the hourly curve silently
                    // renders fabricated numbers indistinguishable from a
                    // quiet real day.
                    if let err = energy.lastError {
                        HStack(alignment: .top, spacing: 10) {
                            Rectangle()
                                .fill(T3.danger)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data unavailable")
                                    .font(T3.inter(13, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                Text(err)
                                    .font(T3.inter(12, weight: .regular))
                                    .foregroundStyle(T3.sub)
                                    .lineLimit(3)
                            }
                            Spacer()
                            Button {
                                Task { await energy.refresh() }
                            } label: {
                                Text("RETRY")
                                    .font(T3.mono(10))
                                    .tracking(1.4)
                                    .foregroundStyle(T3.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) { TRule() }
                    }

                    // Big number
                    VStack(alignment: .leading, spacing: 0) {
                        TLabel(text: "Total today")

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(energy.todayKwh.map { String(format: "%.1f", $0) } ?? "—")
                                .font(T3.inter(120, weight: .light))
                                .tracking(-5)
                                .foregroundStyle(T3.ink)
                                .monospacedDigit()

                            Text(" kWh")
                                .font(T3.inter(36, weight: .light))
                                .foregroundStyle(T3.accent)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                        // Trend — only when both values present
                        HStack(spacing: 4) {
                            if let today = energy.todayKwh, let yesterday = energy.yesterdayKwh, yesterday > 0 {
                                let delta = (today - yesterday) / yesterday
                                let arrow = delta < 0 ? "↓" : "↑"
                                Text("\(arrow) \(Int(abs(delta) * 100))%")
                                    .font(T3.inter(13, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                Text("vs. yesterday (\(String(format: "%.1f", yesterday)) kWh)")
                                    .font(T3.inter(13, weight: .regular))
                                    .foregroundStyle(T3.sub)
                            } else {
                                Text("—")
                                    .font(T3.inter(13, weight: .regular))
                                    .foregroundStyle(T3.sub)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 24)

                    TRule()

                    // Hourly bar chart
                    TSectionHead(title: "Hourly", count: "24h")

                    hourlyChart
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 20)

                    TRule()

                    // By category
                    let cats = energy.categories ?? []
                    TSectionHead(title: "By category", count: String(format: "%02d", cats.count))

                    ForEach(Array(cats.enumerated()), id: \.offset) { i, cat in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(cat.name)
                                    .font(T3.inter(15, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                Spacer()
                                Text("\(Int(cat.fraction * 100))%")
                                    .font(T3.mono(11))
                                    .foregroundStyle(T3.sub)
                                    .tracking(0.5)
                                Text(String(format: "%.1f kWh", cat.kwh))
                                    .font(T3.inter(16, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                    .monospacedDigit()
                            }

                            // Progress bar
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(i == 0 ? T3.accent : T3.ink)
                                    .frame(width: geo.size.width * cat.fraction, height: 3)
                            }
                            .frame(height: 3)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) {
                            if i == cats.count - 1 { TRule() }
                        }
                    }

                    TRule()

                    // Stats
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            TLabel(text: "This Month")
                            Text(energy.monthKwh.map { "\(Int($0)) kWh" } ?? "—")
                                .font(T3.inter(16, weight: .medium))
                                .foregroundStyle(T3.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            TLabel(text: "Est. Cost")
                            Text(energy.estMonthCostUSD.map { String(format: "$%.2f", $0) } ?? "—")
                                .font(T3.inter(16, weight: .medium))
                                .foregroundStyle(T3.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)

                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await energy.refresh()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if energy.lastUpdated == nil {
                await energy.refresh()
            }
        }
    }

    // MARK: - Hourly Chart

    private var hourlyChart: some View {
        let series = energy.hourly ?? Self.hourlyFallback
        let isLive = energy.hourly != nil
        let maxVal = series.max() ?? 1
        let currentHour = Calendar.current.component(.hour, from: Date())

        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<min(24, series.count), id: \.self) { i in
                    Rectangle()
                        .fill(i == currentHour ? T3.accent : T3.ink)
                        .opacity(isLive ? 1.0 : 0.2)
                        .frame(height: CGFloat(series[i] / maxVal) * 120)
                }
            }
            .frame(height: 120)

            // Axis labels
            HStack {
                TLabel(text: "00")
                Spacer()
                TLabel(text: "06")
                Spacer()
                TLabel(text: "12")
                Spacer()
                TLabel(text: "18")
                Spacer()
                TLabel(text: "24")
            }
        }
    }
}

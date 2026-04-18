//
//  T3EnergyView.swift
//  house connect
//
//  T3/Swiss Energy dashboard — daily kWh, hourly bar chart,
//  by-category breakdown. All data placeholder for now.
//
//  ⚠️ FLAG: This screen uses hardcoded energy data since
//  HA doesn't expose energy in a standardized way yet.
//  Will need a real energy integration (HA Energy dashboard
//  entities) to make this data-driven.
//

import SwiftUI

struct T3EnergyView: View {
    @Environment(\.dismiss) private var dismiss

    // Placeholder energy data (from design handoff)
    private let todayKWh: Double = 14.2
    private let yesterdayKWh: Double = 16.8
    private let hourly: [Double] = [0.4,0.3,0.3,0.3,0.3,0.4,0.9,1.2,0.8,0.6,0.5,0.5,0.7,0.6,0.5,0.6,0.9,1.3,1.4,1.2,0.9,0.7,0.5,0.4]
    private let categories: [(String, Double, Double)] = [
        ("Climate", 7.2, 0.51),
        ("Lighting", 3.1, 0.22),
        ("Media", 2.4, 0.17),
        ("Other", 1.5, 0.10),
    ]

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Home", onBack: { dismiss() })

                    // Big number
                    VStack(alignment: .leading, spacing: 0) {
                        TLabel(text: "Total today")

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(String(format: "%.1f", todayKWh))
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

                        // Trend
                        HStack(spacing: 4) {
                            Text("↓ 15%")
                                .font(T3.inter(13, weight: .medium))
                                .foregroundStyle(T3.ink)
                            Text("vs. yesterday (\(String(format: "%.1f", yesterdayKWh)) kWh)")
                                .font(T3.inter(13, weight: .regular))
                                .foregroundStyle(T3.sub)
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
                    TSectionHead(title: "By category", count: String(format: "%02d", categories.count))

                    ForEach(Array(categories.enumerated()), id: \.offset) { i, cat in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(cat.0)
                                    .font(T3.inter(15, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                Spacer()
                                Text("\(Int(cat.2 * 100))%")
                                    .font(T3.mono(11))
                                    .foregroundStyle(T3.sub)
                                    .tracking(0.5)
                                Text(String(format: "%.1f kWh", cat.1))
                                    .font(T3.inter(16, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                    .monospacedDigit()
                            }

                            // Progress bar
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(i == 0 ? T3.accent : T3.ink)
                                    .frame(width: geo.size.width * cat.2, height: 3)
                            }
                            .frame(height: 3)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) {
                            if i == categories.count - 1 { TRule() }
                        }
                    }

                    TRule()

                    // Stats
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            TLabel(text: "This Month")
                            Text("312 kWh")
                                .font(T3.inter(16, weight: .medium))
                                .foregroundStyle(T3.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            TLabel(text: "Est. Cost")
                            Text("$47.20")
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
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hourly Chart

    private var hourlyChart: some View {
        let maxVal = hourly.max() ?? 1
        let currentHour = 18 // Highlighted hour from design

        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { i in
                    Rectangle()
                        .fill(i == currentHour ? T3.accent : T3.ink)
                        .frame(height: CGFloat(hourly[i] / maxVal) * 120)
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

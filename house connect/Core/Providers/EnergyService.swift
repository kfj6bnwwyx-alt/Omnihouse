//
//  EnergyService.swift
//  house connect
//
//  Provides energy statistics (today/yesterday kWh, hourly breakdown,
//  category split, monthly totals) to T3EnergyView and any future
//  energy-aware surface.
//
//  Backend status: PLACEHOLDER. Home Assistant exposes energy via
//  the recorder integration's `recorder/statistics_during_period`
//  WebSocket command, but HomeAssistantProvider/HomeAssistantWebSocketClient
//  don't surface statistics requests yet. Until that wiring lands,
//  `refresh()` generates deterministic mock values seeded off the
//  current date so the dashboard varies day-to-day while staying
//  stable within a session.
//
//  Consumers should render em-dashes (per the SmokeAlarm placeholder
//  pattern) while values are nil, then update once `refresh()`
//  resolves.
//

import Foundation

/// Shared energy statistics surface. Inject at app scope.
@Observable
final class EnergyService {
    /// Total kWh consumed since local midnight today.
    var todayKwh: Double?
    /// Total kWh consumed in the previous local day (for trend comparison).
    var yesterdayKwh: Double?
    /// 24-hour usage, index 0 = 00:00, index 23 = 23:00. kWh per hour.
    var hourly: [Double]?
    /// Breakdown by category (name, kWh, fraction-of-total in 0...1).
    var categories: [EnergyCategory]?
    /// Total kWh consumed so far this calendar month.
    var monthKwh: Double?
    /// Estimated cost this month in USD. Uses a placeholder $0.15/kWh
    /// until a rate plan surface exists.
    var estMonthCostUSD: Double?

    /// Timestamp of the last successful refresh.
    var lastUpdated: Date?

    init() {}

    /// Refresh all energy metrics.
    ///
    /// TODO(HA): replace with a real `recorder/statistics_during_period`
    /// call via HomeAssistantWebSocketClient once the statistics
    /// command envelope is wired. Current implementation returns
    /// deterministic mock data derived from `Date()` so the screen
    /// renders plausible numbers without a live backend.
    func refresh() async {
        // Seed off the calendar day so values are stable within a day
        // but vary day-to-day — keeps the dashboard feeling alive.
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 100
        let seed = Double(day)

        let today = 12.0 + (seed.truncatingRemainder(dividingBy: 8))
        let yesterday = today * (1.0 + (seed.truncatingRemainder(dividingBy: 3) - 1.0) * 0.1)

        // Hourly curve: low overnight, morning bump, evening peak.
        let base: [Double] = [0.4,0.3,0.3,0.3,0.3,0.4,0.9,1.2,0.8,0.6,0.5,0.5,
                              0.7,0.6,0.5,0.6,0.9,1.3,1.4,1.2,0.9,0.7,0.5,0.4]
        let scale = today / base.reduce(0, +)
        let curve = base.map { $0 * scale }

        let climate = today * 0.51
        let lighting = today * 0.22
        let media = today * 0.17
        let other = today - climate - lighting - media
        let cats: [EnergyCategory] = [
            EnergyCategory(name: "Climate", kwh: climate, fraction: 0.51),
            EnergyCategory(name: "Lighting", kwh: lighting, fraction: 0.22),
            EnergyCategory(name: "Media", kwh: media, fraction: 0.17),
            EnergyCategory(name: "Other", kwh: other, fraction: max(0.01, other / today)),
        ]

        let dayOfMonth = calendar.component(.day, from: Date())
        let month = today * Double(dayOfMonth) * 0.95
        let cost = month * 0.15

        // Apply on the main actor — @Observable mutations should come
        // from a consistent context.
        await MainActor.run {
            self.todayKwh = today
            self.yesterdayKwh = yesterday
            self.hourly = curve
            self.categories = cats
            self.monthKwh = month
            self.estMonthCostUSD = cost
            self.lastUpdated = Date()
        }
    }
}

/// One row in the energy category breakdown.
struct EnergyCategory: Hashable, Sendable {
    /// Display label (e.g. "Climate", "Lighting").
    let name: String
    /// kWh consumed in this category today.
    let kwh: Double
    /// Share of the day's total, in 0...1. Pre-computed so the view
    /// doesn't have to normalize.
    let fraction: Double
}

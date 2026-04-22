//
//  EnergyService.swift
//  house connect
//
//  Provides energy statistics (today/yesterday kWh, hourly breakdown,
//  category split, monthly totals) to T3EnergyView and any future
//  energy-aware surface.
//
//  Backend: Home Assistant's `recorder/statistics_during_period`
//  WebSocket command (via HomeAssistantProvider.fetchEnergyStatistics).
//  If HA is unreachable, the configured sensor is missing, or the
//  response can't be parsed, the service falls back to deterministic
//  mock values seeded off the current date so T3EnergyView always
//  renders *something*. Failures are logged under the "energy"
//  os.Logger category.
//
//  Consumers should render em-dashes (per the SmokeAlarm placeholder
//  pattern) while values are nil, then update once `refresh()`
//  resolves.
//

import Foundation
import os

private let energyLog = Logger(subsystem: "com.houseconnect.app", category: "energy")

/// Shared energy statistics surface. Inject at app scope.
@MainActor
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

    /// Non-nil when the most recent refresh fell back to mock data
    /// (HA unreachable, bad entity ID, decode failure). Cleared on
    /// the next successful HA fetch. Views can read this to surface
    /// "Data unavailable" instead of presenting the mock curve as
    /// if it were live.
    var lastError: String?

    /// Optional handle to the provider registry so `refresh()` can
    /// locate the Home Assistant provider and request recorder
    /// statistics. Nil = fall back to mock data immediately (used by
    /// previews and unit tests).
    private weak var registry: ProviderRegistry?

    /// Default $/kWh used when the user hasn't configured a rate in
    /// Settings → Energy. Roughly the US residential average.
    static let defaultRateUSDPerKwh: Double = 0.15

    /// UserDefaults key for the user-selected HA energy sensor entity
    /// ID. Mirrors `@AppStorage("energy.entityID")` in the settings
    /// surface, so reads/writes go through the same bucket.
    static let entityIDDefaultsKey: String = "energy.entityID"

    /// UserDefaults key for the user-configured $/kWh rate. Mirrors
    /// `@AppStorage("energy.ratePerKwh")`.
    static let ratePerKwhDefaultsKey: String = "energy.ratePerKwh"

    /// Resolve the currently-configured energy sensor entity ID.
    /// Falls back to the HA provider's default when the user hasn't
    /// picked one yet.
    private var configuredEntityID: String {
        let stored = UserDefaults.standard.string(forKey: Self.entityIDDefaultsKey) ?? ""
        return stored.isEmpty ? HomeAssistantProvider.defaultEnergyStatisticID : stored
    }

    /// Resolve the currently-configured $/kWh rate, falling back to the
    /// default when the user hasn't set one.
    private var configuredRateUSDPerKwh: Double {
        let stored = UserDefaults.standard.double(forKey: Self.ratePerKwhDefaultsKey)
        return stored > 0 ? stored : Self.defaultRateUSDPerKwh
    }

    init(registry: ProviderRegistry? = nil) {
        self.registry = registry
    }

    /// Allow the registry to be injected after init (e.g. when both
    /// objects are created at app scope and wired up together).
    func attach(registry: ProviderRegistry) {
        self.registry = registry
    }

    /// Refresh all energy metrics. Tries HA recorder statistics first;
    /// falls back to deterministic mock data on any failure so the UI
    /// never stays empty.
    func refresh() async {
        if let ha = registry?.provider(for: .homeAssistant) as? HomeAssistantProvider {
            do {
                try await refreshFromHomeAssistant(ha)
                lastError = nil
                return
            } catch {
                energyLog.warning("HA energy fetch failed, falling back to mock: \(error.localizedDescription, privacy: .public)")
                lastError = error.localizedDescription
            }
        } else {
            energyLog.info("No HA provider registered — using mock energy data")
            lastError = "Home Assistant not connected"
        }
        applyMockData()
    }

    /// Pull hourly (24h) + daily (30d) statistics from HA and populate
    /// the observable properties. Throws on any failure so `refresh()`
    /// can decide whether to fall back.
    private func refreshFromHomeAssistant(_ ha: HomeAssistantProvider) async throws {
        let entityID = configuredEntityID
        // Hourly for the last 24h (used for today/yesterday splits and
        // the hourly chart).
        let hourlyEntries = try await ha.fetchEnergyStatistics(
            period: .hour,
            lookback: .seconds(60 * 60 * 48),   // 48h so we can compute yesterday too
            statisticID: entityID
        )
        // Daily for the month-so-far total.
        let dailyEntries = try await ha.fetchEnergyStatistics(
            period: .day,
            lookback: .seconds(60 * 60 * 24 * 31),
            statisticID: entityID
        )

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            throw NSError(domain: "EnergyService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "calendar math failed"])
        }

        // HA `sum` is cumulative kWh. Per-period consumption is the
        // delta between consecutive sums, which is more reliable than
        // `state` (which may be instantaneous meter reading).
        let hourlyKwh = perPeriodKwh(from: hourlyEntries)

        // Build 24-entry hour-indexed curve for today.
        var hourly = Array(repeating: 0.0, count: 24)
        var todayTotal = 0.0
        var yesterdayTotal = 0.0
        for (entry, kwh) in hourlyKwh {
            guard let start = entry.startDate else { continue }
            if start >= startOfToday {
                let hour = calendar.component(.hour, from: start)
                if hour >= 0 && hour < 24 { hourly[hour] += kwh }
                todayTotal += kwh
            } else if start >= startOfYesterday && start < startOfToday {
                yesterdayTotal += kwh
            }
        }

        let dailyKwh = perPeriodKwh(from: dailyEntries)
        var monthTotal = 0.0
        for (entry, kwh) in dailyKwh {
            guard let start = entry.startDate else { continue }
            if start >= startOfMonth { monthTotal += kwh }
        }

        // Without device-level submetering from HA we can't build a
        // real category split. Leave as nil — T3EnergyView's category
        // section will simply render no rows, which is the honest UI.
        self.todayKwh = todayTotal
        self.yesterdayKwh = yesterdayTotal
        self.hourly = hourly
        self.categories = nil
        self.monthKwh = monthTotal
        self.estMonthCostUSD = monthTotal * configuredRateUSDPerKwh
        self.lastUpdated = Date()
    }

    /// Convert cumulative `sum` entries into per-period kWh deltas.
    /// Falls back to `state` if `sum` is missing on all rows (some
    /// sensors expose only state).
    private func perPeriodKwh(from entries: [StatisticsEntry]) -> [(StatisticsEntry, Double)] {
        // Sort chronologically to make delta math deterministic.
        let sorted = entries.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        let hasSum = sorted.contains { $0.sum != nil }
        if hasSum {
            var result: [(StatisticsEntry, Double)] = []
            var previous: Double?
            for entry in sorted {
                guard let current = entry.sum else { continue }
                if let previous {
                    result.append((entry, max(0, current - previous)))
                }
                previous = current
            }
            return result
        } else {
            return sorted.compactMap { entry in
                entry.state.map { (entry, $0) }
            }
        }
    }

    /// Deterministic mock data, seeded by the calendar day. Used when
    /// HA is unreachable or no provider registry was injected.
    private func applyMockData() {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 100
        let seed = Double(day)

        let today = 12.0 + (seed.truncatingRemainder(dividingBy: 8))
        let yesterday = today * (1.0 + (seed.truncatingRemainder(dividingBy: 3) - 1.0) * 0.1)

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
        let cost = month * configuredRateUSDPerKwh

        self.todayKwh = today
        self.yesterdayKwh = yesterday
        self.hourly = curve
        self.categories = cats
        self.monthKwh = month
        self.estMonthCostUSD = cost
        self.lastUpdated = Date()
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

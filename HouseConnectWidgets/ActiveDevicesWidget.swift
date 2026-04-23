//
//  ActiveDevicesWidget.swift
//  HouseConnectWidgets
//
//  "What's on in the house right now" — a home-screen widget mirror
//  of the Home dashboard's active-devices section. One Active total
//  on the left, three sub-counts on the right (Lights / Playing /
//  Climate). Tapping the widget deep-links into the app.
//
//  Data source today: placeholder snapshot, matching the pattern
//  used by ThermostatWidget / CameraWidget / SceneRunWidget. Once
//  the App Group entitlement is added to both the app target AND
//  HouseConnectWidgets (in Xcode → Signing & Capabilities), the
//  provider reads from `SharedActiveDevicesSnapshot` below and the
//  counts go live. Until then the widget renders realistic demo
//  numbers so layout work and review can happen in parallel.
//
//  Design matches the Home section's hero counts — single orange
//  dot for "active" signal, mono uppercase labels, cream page, jet
//  ink numbers, hairline dividers. No color fills, no rounding.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Snapshot model

/// Compact, Codable representation of the three active-device
/// counts the widget shows. The main app will write this to a
/// shared App Group UserDefaults suite; the widget reads it on
/// every timeline refresh.
///
/// Intentionally NOT sharing `Accessory` / `Capability` with the
/// widget target — those live in the app's module and would
/// require cross-target source membership. A flat snapshot keeps
/// the contract narrow.
struct ActiveDevicesSnapshot: Codable, Hashable {
    var lightsOn: Int
    var nowPlaying: Int
    var climateActive: Int
    /// When the snapshot was written by the main app. Widgets use
    /// this to render "UPDATED 2m AGO" so a stale snapshot is
    /// visible as stale.
    var updatedAt: Date

    var total: Int { lightsOn + nowPlaying + climateActive }

    /// Placeholder used until App Group shared storage lands.
    /// Picks counts typical of a medium-sized home so the tile
    /// looks alive in previews and review screenshots.
    static let placeholder = ActiveDevicesSnapshot(
        lightsOn: 2,
        nowPlaying: 1,
        climateActive: 1,
        updatedAt: Date()
    )

    /// All-zero snapshot for the "quiet house" preview.
    static let quiet = ActiveDevicesSnapshot(
        lightsOn: 0,
        nowPlaying: 0,
        climateActive: 0,
        updatedAt: Date()
    )
}

// MARK: - Shared-storage shim

/// Reads / writes the active-devices snapshot to an App Group
/// shared UserDefaults suite. No-op (returns placeholder) until
/// the `group.house-connect.shared` entitlement is added to both
/// targets — matches the pattern from sibling widgets.
///
/// **To go live:**
///   1. In Xcode select the `house connect` app target →
///      Signing & Capabilities → + Capability → App Groups.
///      Add `group.house-connect.shared`.
///   2. Repeat for the `HouseConnectWidgetsExtension` target.
///   3. The main app should write on every `ActiveDevicesFilter`
///      recomputation (e.g. from `T3HomeDashboardView.task`).
enum SharedActiveDevicesSnapshot {
    private static let suiteName = "group.house-connect.shared"
    private static let key = "activeDevicesSnapshot.v1"

    static func read() -> ActiveDevicesSnapshot {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ActiveDevicesSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return decoded
    }

    static func write(_ snapshot: ActiveDevicesSnapshot) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Timeline entry

struct ActiveDevicesEntry: TimelineEntry {
    let date: Date
    let snapshot: ActiveDevicesSnapshot
}

// MARK: - Provider

struct ActiveDevicesProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveDevicesEntry {
        ActiveDevicesEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveDevicesEntry) -> Void) {
        let snap = context.isPreview ? .placeholder : SharedActiveDevicesSnapshot.read()
        completion(ActiveDevicesEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveDevicesEntry>) -> Void) {
        // Refresh every 5 minutes — active-device state can
        // change frequently but the system throttles widgets
        // anyway, so asking for more is wasted budget.
        let now = Date()
        let snap = SharedActiveDevicesSnapshot.read()
        let entry = ActiveDevicesEntry(date: now, snapshot: snap)
        let next = now.addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct ActiveDevicesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActiveDevicesEntry

    var body: some View {
        switch family {
        case .systemSmall:  smallLayout
        case .systemMedium: mediumLayout
        default:            mediumLayout
        }
    }

    // MARK: Small

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(entry.snapshot.total)")
                    .font(T3.inter(48, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .monospacedDigit()
                Text("active")
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
            }
            Spacer(minLength: 0)
            TRule()
            subCounts
                .padding(.top, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(T3.page, for: .widget)
    }

    // MARK: Medium

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(entry.snapshot.total)")
                        .font(T3.inter(72, weight: .medium))
                        .tracking(-2)
                        .foregroundStyle(T3.ink)
                        .monospacedDigit()
                    Text("active")
                        .font(T3.inter(15, weight: .regular))
                        .foregroundStyle(T3.sub)
                }
                TLabel(text: updatedCaption)
                    .padding(.top, 6)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Rectangle().fill(T3.rule).frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                categoryRow(label: "Lights", value: entry.snapshot.lightsOn, isLast: false)
                categoryRow(label: "Playing", value: entry.snapshot.nowPlaying, isLast: false)
                categoryRow(label: "Climate", value: entry.snapshot.climateActive, isLast: true)
            }
            .frame(width: 140)
            .padding(.vertical, 14)
        }
        .containerBackground(T3.page, for: .widget)
    }

    // MARK: Shared pieces

    private var header: some View {
        HStack(spacing: 6) {
            TDot(size: entry.snapshot.total > 0 ? 7 : 5,
                 color: entry.snapshot.total > 0 ? T3.accent : T3.rule)
            TLabel(text: "House Connect")
        }
    }

    private var subCounts: some View {
        HStack(spacing: 10) {
            subCount(label: "L", value: entry.snapshot.lightsOn)
            subCount(label: "P", value: entry.snapshot.nowPlaying)
            subCount(label: "C", value: entry.snapshot.climateActive)
        }
    }

    private func subCount(label: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(T3.mono(10))
                .tracking(1.2)
                .foregroundStyle(T3.sub)
            Text("\(value)")
                .font(T3.inter(13, weight: .medium))
                .foregroundStyle(T3.ink)
                .monospacedDigit()
        }
    }

    private func categoryRow(label: String, value: Int, isLast: Bool) -> some View {
        HStack {
            Text(label.uppercased())
                .font(T3.mono(10))
                .tracking(1.4)
                .foregroundStyle(T3.sub)
            Spacer()
            Text("\(value)")
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { if !isLast { TRule() } }
    }

    private var updatedCaption: String {
        let elapsed = Date().timeIntervalSince(entry.snapshot.updatedAt)
        if elapsed < 60 { return "UPDATED JUST NOW" }
        if elapsed < 3600 {
            return "UPDATED \(Int(elapsed / 60))M AGO"
        }
        return "UPDATED \(Int(elapsed / 3600))H AGO"
    }
}

// MARK: - Widget declaration

struct ActiveDevicesWidget: Widget {
    let kind: String = "com.houseconnect.activeDevices"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveDevicesProvider()) { entry in
            ActiveDevicesWidgetView(entry: entry)
        }
        .configurationDisplayName("Active Devices")
        .description("A glance at what's on in the house right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview("Small · Active", as: .systemSmall) {
    ActiveDevicesWidget()
} timeline: {
    ActiveDevicesEntry(date: .now, snapshot: .placeholder)
}

#Preview("Small · Quiet", as: .systemSmall) {
    ActiveDevicesWidget()
} timeline: {
    ActiveDevicesEntry(date: .now, snapshot: .quiet)
}

#Preview("Medium · Active", as: .systemMedium) {
    ActiveDevicesWidget()
} timeline: {
    ActiveDevicesEntry(date: .now, snapshot: .placeholder)
}

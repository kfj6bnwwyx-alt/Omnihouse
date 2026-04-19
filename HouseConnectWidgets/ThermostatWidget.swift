//
//  ThermostatWidget.swift
//  HouseConnectWidgets
//
//  Pencil `45PoD` — Home screen widget for a thermostat. Shows the room
//  name, current target temp, a segmented bar representing position in
//  the min-max range, the mode label, and current temp + humidity.
//
//  Wave EE (2026-04-18): Converted from StaticConfiguration to
//  AppIntentConfiguration so users can long-press the widget → Edit Widget
//  and pick which thermostat entity to display (Brent now has two Nest
//  thermostats live in Home Assistant: bedroom + family room).
//
//  The live data path still reads placeholder values — the main app does
//  not yet write thermostat snapshots to a shared App Group. When that
//  lands, the provider can simply key into the shared defaults using
//  `configuration.thermostat.id` to pull the matching entry. For now the
//  selection drives `roomName` and the entry identity so each widget
//  instance visually reflects the user's pick.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Thermostat entity

/// An `AppEntity` representing a single Home Assistant `climate.*` entity.
/// Surfaced to the widget configuration UI so the user can pick which
/// thermostat each widget instance shows.
struct ThermostatEntity: AppEntity, Identifiable, Hashable {
    /// Home Assistant entity id (e.g. `climate.bedroom_thermostat`).
    var id: String
    /// Friendly name rendered in the widget header.
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Thermostat")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = ThermostatEntityQuery()

    /// Hard-coded set of known thermostats Brent has live in Home Assistant.
    /// When the App Group shared-storage contract lands, this list should
    /// be rehydrated from `UserDefaults(suiteName:)` instead.
    static let allKnown: [ThermostatEntity] = [
        ThermostatEntity(id: "climate.bedroom_thermostat", name: "Bedroom"),
        ThermostatEntity(id: "climate.family_room_thermostat", name: "Family Room")
    ]
}

struct ThermostatEntityQuery: EntityQuery {
    func entities(for identifiers: [ThermostatEntity.ID]) async throws -> [ThermostatEntity] {
        ThermostatEntity.allKnown.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ThermostatEntity] {
        ThermostatEntity.allKnown
    }

    func defaultResult() async -> ThermostatEntity? {
        ThermostatEntity.allKnown.first
    }
}

// MARK: - Configuration intent

struct ThermostatSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Thermostat"
    static var description = IntentDescription("Choose which thermostat this widget should display.")

    @Parameter(title: "Thermostat")
    var thermostat: ThermostatEntity?
}

// MARK: - Timeline

struct ThermostatWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ThermostatWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: ThermostatSelectionIntent, in context: Context) async -> ThermostatWidgetEntry {
        entry(for: configuration.thermostat)
    }

    func timeline(for configuration: ThermostatSelectionIntent, in context: Context) async -> Timeline<ThermostatWidgetEntry> {
        let entry = entry(for: configuration.thermostat)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
    }

    /// Builds an entry for the selected thermostat. Values other than the
    /// room name stay at placeholder defaults until the App Group shared
    /// snapshot path is wired up.
    private func entry(for selection: ThermostatEntity?) -> ThermostatWidgetEntry {
        let resolved = selection ?? ThermostatEntity.allKnown.first ?? ThermostatEntity(id: "climate.unknown", name: "Thermostat")
        return ThermostatWidgetEntry(
            date: Date(),
            entityID: resolved.id,
            roomName: resolved.name,
            targetTemp: 72,
            currentTemp: 71,
            humidity: 45,
            mode: "Heating",
            useFahrenheit: true,
            rangeMin: 60,
            rangeMax: 85
        )
    }
}

struct ThermostatWidgetEntry: TimelineEntry {
    let date: Date
    let entityID: String
    let roomName: String
    let targetTemp: Int
    let currentTemp: Int
    let humidity: Int
    let mode: String
    let useFahrenheit: Bool
    let rangeMin: Int
    let rangeMax: Int

    static let placeholder = ThermostatWidgetEntry(
        date: Date(),
        entityID: "climate.placeholder",
        roomName: "Living Room",
        targetTemp: 72,
        currentTemp: 71,
        humidity: 45,
        mode: "Heating",
        useFahrenheit: true,
        rangeMin: 60,
        rangeMax: 85
    )
}

// MARK: - View

struct ThermostatWidgetView: View {
    let entry: ThermostatWidgetEntry

    private var unitSuffix: String { entry.useFahrenheit ? "°F" : "°C" }

    /// How far the target is through the range, 0...1.
    private var targetFraction: CGFloat {
        let range = CGFloat(entry.rangeMax - entry.rangeMin)
        guard range > 0 else { return 0.5 }
        return CGFloat(entry.targetTemp - entry.rangeMin) / range
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: room name + mode label
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(T3.sub)
                    Text(entry.roomName)
                        .font(T3.inter(14, weight: .semibold))
                        .foregroundStyle(T3.ink)
                }
                Spacer()
                HStack(spacing: 6) {
                    TDot(size: 6, color: T3.accent)
                    TLabel(text: entry.mode, color: T3.accent)
                }
            }

            // Big target temperature — tabular digits
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.targetTemp)")
                    .font(T3.inter(44, weight: .medium))
                    .tracking(-1.2)
                    .monospacedDigit()
                    .foregroundStyle(T3.ink)
                Text(unitSuffix)
                    .font(T3.inter(16, weight: .regular))
                    .foregroundStyle(T3.sub)
                Spacer()
            }

            // Segmented temperature bar
            temperatureBar

            TRule()

            // Footer: current temp + humidity
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TLabel(text: "Current")
                    Text("\(entry.currentTemp)\(unitSuffix)")
                        .font(T3.inter(13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(T3.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    TLabel(text: "Humidity")
                    Text("\(entry.humidity)%")
                        .font(T3.inter(13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(T3.ink)
                }
            }
        }
        .padding(14)
        .background(T3.page)
    }

    // MARK: - Temperature bar

    /// Blocky segmented bar. Flat cells (no rounding), ink-filled up
    /// to the target, rule-gray after. Min/target/max labels below.
    private var temperatureBar: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let totalSegments = 16
                let filledCount = Int(targetFraction * CGFloat(totalSegments))
                let segmentWidth = (proxy.size.width - CGFloat(totalSegments - 1) * 2) / CGFloat(totalSegments)

                HStack(spacing: 2) {
                    ForEach(0..<totalSegments, id: \.self) { i in
                        Rectangle()
                            .fill(i < filledCount ? T3.ink : T3.rule)
                            .frame(width: segmentWidth)
                    }
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(entry.rangeMin)°")
                    .font(T3.mono(9))
                    .tracking(1.2)
                    .monospacedDigit()
                    .foregroundStyle(T3.sub)
                Spacer()
                Text("\(entry.targetTemp)°")
                    .font(T3.mono(9))
                    .tracking(1.2)
                    .monospacedDigit()
                    .foregroundStyle(T3.accent)
                Spacer()
                Text("\(entry.rangeMax)°")
                    .font(T3.mono(9))
                    .tracking(1.2)
                    .monospacedDigit()
                    .foregroundStyle(T3.sub)
            }
        }
    }
}

// MARK: - Widget

struct ThermostatWidget: Widget {
    let kind = "ThermostatWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ThermostatSelectionIntent.self,
            provider: ThermostatWidgetProvider()
        ) { entry in
            ThermostatWidgetView(entry: entry)
                .containerBackground(T3.page, for: .widget)
        }
        .configurationDisplayName("Thermostat")
        .description("Glance at a thermostat's target, current temperature, and humidity. Long-press to pick which thermostat.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    ThermostatWidget()
} timeline: {
    ThermostatWidgetEntry.placeholder
}

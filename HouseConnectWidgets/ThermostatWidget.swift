//
//  ThermostatWidget.swift
//  HouseConnectWidgets
//
//  Pencil `45PoD` — Home screen widget for a thermostat. Shows the room
//  name, current target temp, a segmented bar representing position in
//  the min-max range, the mode label, and current temp + humidity.
//
//  Reads placeholder data until the App Group shared container is wired.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ThermostatWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ThermostatWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ThermostatWidgetEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ThermostatWidgetEntry>) -> Void) {
        let entry = ThermostatWidgetEntry.placeholder
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct ThermostatWidgetEntry: TimelineEntry {
    let date: Date
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
        StaticConfiguration(kind: kind, provider: ThermostatWidgetProvider()) { entry in
            ThermostatWidgetView(entry: entry)
                .containerBackground(T3.page, for: .widget)
        }
        .configurationDisplayName("Thermostat")
        .description("Glance at your thermostat's target, current temperature, and humidity.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    ThermostatWidget()
} timeline: {
    ThermostatWidgetEntry.placeholder
}

//
//  ThermostatWidget.swift
//  HouseConnectWidgets
//
//  Pencil `45PoD` — Home screen widget for a thermostat. Shows the room
//  name, current target temp with +/- buttons, a segmented color bar
//  representing the temperature range, mode badge ("Heating"), and
//  current temp + humidity readouts.
//
//  Like the camera widget, this reads from placeholder data until the
//  App Group shared container is wired. The visual design matches the
//  Pencil mockup: large temperature display, interactive-looking (but
//  widget-tap-only) +/- circles, and a blocky gradient strip.
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

    private let accentColor = Color(red: 0.31, green: 0.27, blue: 0.91)

    private var unitSuffix: String { entry.useFahrenheit ? "°F" : "°C" }

    /// How far the target is through the range, 0...1.
    private var targetFraction: CGFloat {
        let range = CGFloat(entry.rangeMax - entry.rangeMin)
        guard range > 0 else { return 0.5 }
        return CGFloat(entry.targetTemp - entry.rangeMin) / range
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header: room name + mode badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text(entry.roomName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text(entry.mode)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(accentColor.opacity(0.12))
                )
            }

            // Temperature display with +/- buttons
            HStack(spacing: 12) {
                // Minus button
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                // Big temperature
                HStack(alignment: .top, spacing: 2) {
                    Text("\(entry.targetTemp)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(unitSuffix)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                // Plus button
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            // Segmented temperature bar
            temperatureBar

            // Footer: current temp + humidity
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(entry.currentTemp)\(unitSuffix)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Humidity")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(entry.humidity)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(14)
    }

    // MARK: - Temperature bar

    /// Blocky segmented bar matching the Pencil comp. Each segment is
    /// a small rounded square; accent-filled up to the target, gray
    /// after. Labels at min, target, and max.
    private var temperatureBar: some View {
        VStack(spacing: 4) {
            // Segments
            GeometryReader { proxy in
                let totalSegments = 16
                let filledCount = Int(targetFraction * CGFloat(totalSegments))
                let segmentWidth = (proxy.size.width - CGFloat(totalSegments - 1) * 2) / CGFloat(totalSegments)

                HStack(spacing: 2) {
                    ForEach(0..<totalSegments, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(i < filledCount ? accentColor : Color.secondary.opacity(0.2))
                            .frame(width: segmentWidth)
                    }
                }
            }
            .frame(height: 14)

            // Labels
            HStack {
                Text("\(entry.rangeMin)°")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.targetTemp)°")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accentColor)
                Spacer()
                Text("\(entry.rangeMax)°")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
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
                .containerBackground(.fill.tertiary, for: .widget)
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

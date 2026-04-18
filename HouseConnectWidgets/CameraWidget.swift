//
//  CameraWidget.swift
//  HouseConnectWidgets
//
//  Pencil `5lYmg` — Home screen widget for a security camera. Shows the
//  camera name, a LIVE badge, a dark placeholder for the feed, timestamp,
//  last motion event, and armed/disarmed status.
//
//  This is a static-timeline widget since the extension doesn't have
//  real-time access to camera frames. The snapshot shows the most recent
//  state from the shared data store (App Groups — wired in a future phase).
//  For now, we render placeholder data so the widget shows up in the
//  gallery and previews correctly.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct CameraWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CameraWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CameraWidgetEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CameraWidgetEntry>) -> Void) {
        // Refresh every 15 min. In a real implementation, read from
        // App Group shared container for the latest camera snapshot.
        let entry = CameraWidgetEntry.placeholder
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct CameraWidgetEntry: TimelineEntry {
    let date: Date
    let cameraName: String
    let isLive: Bool
    let lastMotion: String
    let isArmed: Bool

    static let placeholder = CameraWidgetEntry(
        date: Date(),
        cameraName: "Front Door",
        isLive: true,
        lastMotion: "Motion \u{00B7} 4 min ago",
        isArmed: true
    )
}

// MARK: - View

struct CameraWidgetView: View {
    let entry: CameraWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: camera name + LIVE badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "video")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(T3.sub)
                    Text(entry.cameraName)
                        .font(T3.inter(14, weight: .semibold))
                        .foregroundStyle(T3.ink)
                }
                Spacer()
                if entry.isLive {
                    HStack(spacing: 6) {
                        TDot(size: 6, color: T3.accent)
                        TLabel(text: "Live", color: T3.accent)
                    }
                }
            }

            // Camera feed placeholder — flat, no rounding
            ZStack {
                Rectangle()
                    .fill(T3.ink)

                Image(systemName: "video")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(T3.sub)

                // Timestamp overlay — mono, uppercase
                VStack {
                    Spacer()
                    HStack {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(T3.mono(10))
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        Spacer()
                    }
                    .padding(8)
                }
            }

            TRule()

            // Footer: motion event + armed status
            HStack {
                HStack(spacing: 6) {
                    TDot(size: 6, color: T3.accent)
                    Text(entry.lastMotion)
                        .font(T3.inter(11, weight: .regular))
                        .foregroundStyle(T3.sub)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: entry.isArmed ? "checkmark.shield" : "shield.slash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(entry.isArmed ? T3.ok : T3.sub)
                    TLabel(
                        text: entry.isArmed ? "Armed" : "Disarmed",
                        color: entry.isArmed ? T3.ok : T3.sub
                    )
                }
            }
        }
        .padding(14)
        .background(T3.page)
    }
}

// MARK: - Widget

struct CameraWidget: Widget {
    let kind = "CameraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CameraWidgetProvider()) { entry in
            CameraWidgetView(entry: entry)
                .containerBackground(T3.page, for: .widget)
        }
        .configurationDisplayName("Security Camera")
        .description("Quick glance at your camera feed with motion events.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    CameraWidget()
} timeline: {
    CameraWidgetEntry.placeholder
}

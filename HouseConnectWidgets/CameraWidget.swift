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
        VStack(alignment: .leading, spacing: 8) {
            // Header: camera name + LIVE badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.cameraName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                if entry.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
            }

            // Camera feed placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.11))

                Image(systemName: "video.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(white: 0.3))

                // Timestamp overlay
                VStack {
                    Spacer()
                    HStack {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(.black.opacity(0.5))
                            )
                        Spacer()
                    }
                    .padding(8)
                }
            }

            // Footer: motion event + armed status
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(entry.lastMotion)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: entry.isArmed ? "checkmark.shield.fill" : "shield.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(entry.isArmed ? .green : .secondary)
                    Text(entry.isArmed ? "Armed" : "Disarmed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(entry.isArmed ? .green : .secondary)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Widget

struct CameraWidget: Widget {
    let kind = "CameraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CameraWidgetProvider()) { entry in
            CameraWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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

//
//  SmokeAlertLiveActivity.swift
//  HouseConnectWidgets (widget extension)
//
//  Live Activity surfaces for the smoke-alarm pipeline. Three layouts,
//  matching the Pencil highlights:
//
//    1. `hYUFC` — Dynamic Island COMPACT
//       One-line: warning triangle + "Smoke Detected" + room badge.
//    2. `EY8wa` — Dynamic Island EXPANDED
//       Header (icon + title + timestamp), subtitle (room + device),
//       guidance line, two buttons (Call 911 / Silence).
//    3. `3eyUA` — Lock Screen / Banner
//       Same content as expanded, rendered as a card with rounded
//       corners on the lock screen.
//
//  Buttons don't wire to real actions yet — the bodies are
//  placeholder Links. Once App Intents for these actions exist, swap
//  the Links for `Button(intent:)` calls so taps route back into the
//  main app's SmokeAlertController (see `Core/LiveActivities/` in the
//  main target).
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SmokeAlertLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SmokeAlertAttributes.self) { context in
            // MARK: - Lock screen / banner (Pencil 3eyUA)
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.red)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded (Pencil EY8wa)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.red)
                        .padding(.leading, 4)
                        .accessibilityLabel("Smoke alert warning")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timeAgo(context.state.triggeredAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                        .accessibilityLabel("Alert triggered \(timeAgo(context.state.triggeredAt))")
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smoke Detected")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.red)
                        Text(subtitleLine(context: context))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Smoke Detected, \(subtitleLine(context: context))")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Color.orange)
                                .accessibilityHidden(true)
                            Text(context.state.guidance)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.08))
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Safety guidance: \(context.state.guidance)")

                        HStack(spacing: 8) {
                            actionButton(
                                label: "Call 911",
                                systemImage: "phone.fill",
                                style: .danger,
                                url: URL(string: "tel://911")!
                            )
                            actionButton(
                                label: "Silence",
                                systemImage: "bell.slash.fill",
                                style: .secondary,
                                url: URL(string: "houseconnect://smoke/silence")!
                            )
                        }
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                // MARK: - Compact leading (Pencil hYUFC left)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
                    .accessibilityLabel("Smoke alert")
            } compactTrailing: {
                // MARK: - Compact trailing (Pencil hYUFC right)
                HStack(spacing: 4) {
                    Text(context.attributes.roomName ?? "Home")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.red)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Smoke detected in \(context.attributes.roomName ?? "Home")")
            } minimal: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
                    .accessibilityLabel("Smoke alert active")
            }
            .keylineTint(Color.red)
        }
    }
}

// MARK: - Lock screen presentation

private struct LockScreenView: View {
    let context: ActivityViewContext<SmokeAlertAttributes>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.red)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Smoke Detected")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.red)
                    Spacer()
                    Text(timeAgo(context.state.triggeredAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Smoke Detected, \(timeAgo(context.state.triggeredAt))")

                Text(subtitleLine(context: context))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(subtitleLine(context: context))

                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.orange)
                        .accessibilityHidden(true)
                    Text(context.state.guidance)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Safety guidance: \(context.state.guidance)")

                HStack(spacing: 8) {
                    actionButton(
                        label: "Call 911",
                        systemImage: "phone.fill",
                        style: .danger,
                        url: URL(string: "tel://911")!
                    )
                    actionButton(
                        label: "Silence",
                        systemImage: "bell.slash.fill",
                        style: .secondary,
                        url: URL(string: "houseconnect://smoke/silence")!
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
    }
}

// MARK: - Helpers

private enum ButtonStyleKind { case danger, secondary }

@ViewBuilder
private func actionButton(
    label: String,
    systemImage: String,
    style: ButtonStyleKind,
    url: URL
) -> some View {
    let hint: String = switch (label, style) {
    case ("Call 911", _):
        "Double-tap to call emergency services"
    case ("Silence", _):
        "Double-tap to silence the smoke alarm"
    default:
        ""
    }

    Link(destination: url) {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(style == .danger ? Color.red : Color.white.opacity(0.14))
        )
    }
    .accessibilityLabel(label)
    .accessibilityHint(hint)
}

/// Short "2m ago" formatter. Live Activity surfaces are narrow so we
/// can't afford a full relative formatter — this keeps things crisp.
private func timeAgo(_ date: Date) -> String {
    let seconds = Int(-date.timeIntervalSinceNow)
    if seconds < 60 { return "\(max(seconds, 1))s ago" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = minutes / 60
    return "\(hours)h ago"
}

/// "Living Room · Nest Protect" subtitle used by both lock screen and
/// expanded Dynamic Island. Gracefully drops the room when we don't
/// know it.
private func subtitleLine(context: ActivityViewContext<SmokeAlertAttributes>) -> String {
    let parts = [context.attributes.roomName, context.attributes.deviceName]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    return parts.joined(separator: " · ")
}

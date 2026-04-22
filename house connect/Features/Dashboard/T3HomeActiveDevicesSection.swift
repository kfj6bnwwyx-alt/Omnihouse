//
//  T3HomeActiveDevicesSection.swift
//  house connect
//
//  "What's on in the house right now" — surfaces devices currently
//  doing something, grouped by what kind of thing they're doing.
//  Replaces the Rooms grid that used to live on the Home dashboard
//  (which duplicated the Rooms tab).
//
//  Three sub-sections, each hidden when empty:
//    · Lights on — `.light` category + `isOn == true`
//    · Playing   — media players with playback state == `.playing`
//                  (or, when no playback state is reported, `isOn == true`)
//    · Climate   — thermostats whose HVAC mode is NOT `.off`
//
//  Unreachable devices are filtered from every section — a stale
//  "on" state on a disconnected device is worse than nothing.
//
//  See docs/designs/2026-04-22-home-active-devices-design.md.
//

import SwiftUI

struct T3HomeActiveDevicesSection: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appearance.tempUnit") private var tempUnit: String = "celsius"

    @State private var toast: Toast?

    /// Animation used whenever the list membership changes (row
    /// appears or disappears). Short and decisive — a gentle fade
    /// for reduce-motion users, combined fade+slide-from-top when
    /// motion is OK. Durations match `T3RowButtonStyle`'s easing
    /// vocabulary so the press-state and reveal feel related.
    private var rowAnimation: Animation? {
        reduceMotion ? .none : .easeOut(duration: 0.22)
    }

    private var rowTransition: AnyTransition {
        reduceMotion ? .opacity :
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity
            )
    }

    // MARK: - Filters
    //
    // Computed vars read `registry.allAccessories` so SwiftUI
    // observation tracks the correct dependency graph. The filter
    // logic lives in `ActiveDevicesFilter` so it's unit-testable
    // without mounting the view.

    private var lightsOn: [Accessory] {
        ActiveDevicesFilter.lightsOn(registry.allAccessories)
    }

    private var nowPlaying: [Accessory] {
        ActiveDevicesFilter.nowPlaying(registry.allAccessories)
    }

    private var climateActive: [Accessory] {
        ActiveDevicesFilter.climateActive(registry.allAccessories)
    }

    // MARK: - Body

    /// True when all three active-device sections are empty. The
    /// parent view can render a quiet caption (or not) based on
    /// this; the section itself stays silent.
    var allEmpty: Bool {
        lightsOn.isEmpty && nowPlaying.isEmpty && climateActive.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !lightsOn.isEmpty {
                section(title: "Lights on", count: lightsOn.count) {
                    ForEach(lightsOn, id: \.id) { acc in
                        lightRow(acc, isLast: acc.id == lightsOn.last?.id)
                            .transition(rowTransition)
                    }
                }
                .transition(rowTransition)
            }

            if !nowPlaying.isEmpty {
                section(title: "Playing", count: nowPlaying.count) {
                    ForEach(nowPlaying, id: \.id) { acc in
                        playingRow(acc, isLast: acc.id == nowPlaying.last?.id)
                            .transition(rowTransition)
                    }
                }
                .transition(rowTransition)
            }

            if !climateActive.isEmpty {
                section(title: "Climate", count: climateActive.count) {
                    ForEach(climateActive, id: \.id) { acc in
                        climateRow(acc, isLast: acc.id == climateActive.last?.id)
                            .transition(rowTransition)
                    }
                }
                .transition(rowTransition)
            }
        }
        .animation(rowAnimation, value: lightsOn.map(\.id))
        .animation(rowAnimation, value: nowPlaying.map(\.id))
        .animation(rowAnimation, value: climateActive.map(\.id))
        .toast($toast)
    }

    // MARK: - Section header

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TSectionHead(title: title, count: String(format: "%02d", count))
        content()
    }

    // MARK: - Row variants

    private func lightRow(_ acc: Accessory, isLast: Bool) -> some View {
        let sub: String = {
            let room = roomName(for: acc).uppercased()
            if let brightness = acc.brightness {
                let pct = Int((brightness * 100).rounded())
                return "\(room) · \(pct)%"
            }
            return room
        }()
        return row(
            accessory: acc,
            icon: "lightbulb.fill",
            subtitle: sub,
            isLast: isLast
        )
    }

    private func playingRow(_ acc: Accessory, isLast: Bool) -> some View {
        let room = roomName(for: acc).uppercased()
        let sub: String
        if let np = acc.nowPlaying {
            if let artist = np.artist, !artist.isEmpty {
                sub = "\(room) · \(artist.uppercased())"
            } else if let title = np.title, !title.isEmpty {
                sub = "\(room) · \(title.uppercased())"
            } else {
                sub = "\(room) · PLAYING"
            }
        } else {
            sub = "\(room) · PLAYING"
        }
        return row(
            accessory: acc,
            icon: playingIcon(for: acc),
            subtitle: sub,
            isLast: isLast
        )
    }

    private func climateRow(_ acc: Accessory, isLast: Bool) -> some View {
        let mode = (acc.hvacMode?.rawValue ?? "").uppercased()
        let current = acc.currentTemperature.map { formatTemp($0) } ?? "–"
        let target: String = {
            if case .targetTemperature(let c) = acc.capability(of: .targetTemperature) {
                return formatTemp(c)
            }
            return "–"
        }()
        let sub = "\(mode) · \(current)→\(target)°"
        return row(
            accessory: acc,
            icon: "thermometer.medium",
            subtitle: sub,
            isLast: isLast
        )
    }

    // MARK: - Shared row

    private func row(
        accessory acc: Accessory,
        icon: String,
        subtitle: String,
        isLast: Bool
    ) -> some View {
        HStack(spacing: 14) {
            // Nav-link portion (icon + text + chevron) opens device
            // detail. `.t3Row` button style supplies the press-state
            // highlight so users can feel the tap target.
            NavigationLink(value: acc.id) {
                HStack(spacing: 14) {
                    T3IconImage(systemName: icon)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(T3.ink)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(acc.name)
                            .font(T3.inter(14, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(T3.mono(9))
                            .tracking(1)
                            .foregroundStyle(T3.sub)
                            .lineLimit(1)
                    }
                    Spacer()
                    T3IconImage(systemName: "chevron.right")
                        .frame(width: 10, height: 10)
                        .foregroundStyle(T3.sub)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.t3Row)

            // Toggle sits outside the NavigationLink so tapping it
            // doesn't navigate. Same optimistic-rollback pattern as
            // the detail views.
            TPill(isOn: Binding(
                get: { acc.isOn ?? false },
                set: { newValue in
                    Task { @MainActor in
                        await T3ActionFeedback.perform(
                            action: {
                                try await registry.execute(.setPower(newValue), on: acc.id)
                            },
                            toast: { toast = .error("Couldn't reach \(acc.name)") },
                            errorDescription: "Home active-devices toggle"
                        )
                    }
                }
            ))
            .padding(.trailing, T3.screenPadding)
        }
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    // MARK: - Helpers

    private func roomName(for acc: Accessory) -> String {
        guard let rid = acc.roomID else { return "—" }
        return registry.allRooms
            .first { $0.id == rid && $0.provider == acc.id.provider }?
            .name ?? "—"
    }

    private func playingIcon(for acc: Accessory) -> String {
        switch acc.category {
        case .speaker: return "speaker.wave.2.fill"
        case .appleTV: return "appletv.fill"
        case .television: return "tv.fill"
        default: return "play.fill"
        }
    }

    private func formatTemp(_ celsius: Double) -> String {
        if tempUnit == "fahrenheit" {
            return "\(Int((celsius * 9.0 / 5.0 + 32.0).rounded()))"
        }
        return "\(Int(celsius.rounded()))"
    }
}

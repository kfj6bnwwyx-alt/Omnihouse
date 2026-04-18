//
//  T3Icon.swift
//  house connect
//
//  Bridge from SF Symbol names to the Lucide-based T3/Swiss icon set
//  bundled in `Assets.xcassets/T3Icons/`. The custom glyphs use
//  `stroke-linecap="square"` + `stroke-linejoin="miter"` and have any
//  corner-radius attributes stripped — matching the Braun T3 / Dieter
//  Rams aesthetic (angular, mechanical, no rounded terminals).
//
//  Usage:
//    // Drop-in replacement for Image(systemName:)
//    T3IconImage(systemName: "house.fill")
//        .frame(width: 24, height: 24)
//        .foregroundStyle(T3.ink)
//
//  When a mapping exists, renders the Lucide SVG (template image so
//  it tints with `.foregroundStyle`). When no mapping exists, falls
//  back to SF Symbol — coverage grows incrementally.
//
//  To add a new icon:
//    1. Drop an imageset into Assets.xcassets/T3Icons/ (SVG with
//       rounded→square/miter transform applied)
//    2. Add `"sf.name": "lucide-name"` to `T3Icon.map` below
//

import SwiftUI

/// Bridge table + image view for T3's Lucide-backed icon set.
enum T3Icon {
    /// SF Symbol name → Lucide asset name in `Assets.xcassets/T3Icons/`.
    /// Keys are SF Symbol names exactly as passed to `Image(systemName:)`.
    /// Values are the imageset name (minus `.imageset`).
    static let map: [String: String] = [
        // Chrome / navigation
        "chevron.left": "chevron-left",
        "chevron.right": "chevron-right",
        "chevron.down": "chevron-down",
        "chevron.up": "chevron-up",
        "xmark": "x",
        "xmark.circle.fill": "circle-x",
        "checkmark": "check",
        "checkmark.circle.fill": "circle-check",
        "checkmark.shield.fill": "shield-check",
        "plus": "plus",
        "plus.circle.fill": "circle-plus",
        "minus": "minus",
        "ellipsis": "ellipsis",
        "magnifyingglass": "search",
        "arrow.left": "arrow-left",
        "arrow.up.right": "arrow-up-right",
        "arrow.clockwise": "rotate-cw",
        "arrow.counterclockwise": "rotate-ccw",
        "rectangle.portrait.and.arrow.right": "log-out",
        "line.3.horizontal.decrease": "sliders-horizontal",
        "pencil": "pencil",

        // Tabs / app chrome
        "house": "house",
        "house.fill": "house",
        "square.grid.2x2": "grid-2x2",
        "square.grid.2x2.fill": "grid-2x2",
        "circle.grid.3x3": "grid-3x3",
        "circle.grid.3x3.fill": "grid-3x3",
        "rectangle.on.rectangle": "layers",
        "gearshape": "settings",
        "gearshape.fill": "settings",
        "gearshape.2": "cog",
        "person": "user",

        // Device categories
        "lightbulb": "lightbulb",
        "lightbulb.fill": "lightbulb",
        "thermometer.medium": "thermometer",
        "thermometer": "thermometer",
        "lock": "lock",
        "lock.fill": "lock",
        "lock.open.fill": "lock-open",
        "lock.open": "lock-open",
        "hifispeaker": "speaker",
        "hifispeaker.fill": "speaker",
        "hifispeaker.2.fill": "speaker",
        "hifispeaker.slash": "volume-off",
        "video": "video",
        "video.slash": "video-off",
        "fan": "fan",
        "door.left.hand.open": "door-open",

        // Room icons
        "sofa": "sofa",
        "sofa.fill": "sofa",
        "bed.double": "bed",
        "bed.double.fill": "bed",
        "fork.knife": "utensils",
        "fork.knife.circle.fill": "utensils",
        "leaf.fill": "leaf",

        // Weather / environment
        "sun.max": "sun",
        "sun.max.fill": "sun",
        "cloud": "cloud",
        "cloud.fill": "cloud",
        "moon": "moon",
        "moon.fill": "moon",
        "drop": "droplet",
        "drop.fill": "droplet",
        "wind": "wind",

        // HVAC
        "flame": "flame",
        "flame.fill": "flame",
        "snowflake": "snowflake",
        "power": "power",
        "bolt": "zap",
        "bolt.fill": "zap",
        "bolt.slash": "zap-off",

        // Media transport
        "play": "play",
        "play.fill": "play",
        "play.circle.fill": "circle-play",
        "pause": "pause",
        "pause.fill": "pause",
        "forward.fill": "skip-forward",
        "backward.fill": "skip-back",
        "shuffle": "shuffle",
        "airplayaudio": "airplay",
        "speaker.wave.2.fill": "volume-2",
        "speaker.wave.3.fill": "volume-2",
        "speaker.slash.fill": "volume-x",

        // Status / alerts / misc
        "bell": "bell",
        "bell.slash.fill": "bell-off",
        "wifi": "wifi",
        "wifi.slash": "wifi-off",
        "exclamationmark.triangle": "triangle-alert",
        "exclamationmark.triangle.fill": "triangle-alert",
        "link": "link",
        "link.badge.plus": "link-2",
        "trash": "trash-2",
        "envelope.fill": "mail",
        "phone.fill": "phone",
        "eye.slash": "eye-off",
        "sparkles": "sparkles",
        "sparkle": "sparkle",
        "music.note": "music",
        "target": "target",
        "paintpalette.fill": "palette",
        "photo.artframe": "image",
        "tv": "tv",
        "calendar.badge.clock": "calendar-clock",
        "clock": "clock",
        "clock.badge.questionmark": "clock",
        "dot.radiowaves.left.and.right": "radio",
    ]

    /// Returns the Lucide asset path for an SF Symbol, or nil if unmapped.
    static func asset(for systemName: String) -> String? {
        guard let name = map[systemName] else { return nil }
        return "T3Icons/\(name)"
    }
}

// MARK: - Drop-in Image view

/// SwiftUI image view that prefers a T3 Lucide glyph over an SF Symbol
/// when a mapping exists. Preserves template-tinting semantics so the
/// image colors with `.foregroundStyle(...)` as expected.
struct T3IconImage: View {
    let systemName: String

    var body: some View {
        if let assetPath = T3Icon.asset(for: systemName) {
            Image(assetPath)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: systemName)
        }
    }
}

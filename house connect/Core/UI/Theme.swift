//
//  Theme.swift
//  house connect
//
//  Single source of truth for colors, spacing, corner radii, and typography
//  used by the Pencil-driven visual redesign. Keep this file free of any
//  SwiftUI layout code — it's the palette, nothing else. Views reach for
//  `Theme.color.*` / `Theme.radius.*` by name so we can retune the system
//  from one place without a giant find-and-replace.
//
//  Design reference: /Users/brentbrooks/Documents/pencil/house connect.pen
//  (see Home Dashboard A1WUK for the canonical look).
//

import SwiftUI

enum Theme {
    // MARK: Palette
    //
    // The Pencil file uses a purple-forward palette: selected tiles,
    // toggles, and primary buttons all render in a saturated indigo, with
    // lavender "icon chip" backgrounds behind dark purple glyphs. The page
    // background is a near-white neutral so white cards still read as cards.
    //
    // I'm picking these hex values by eye from the Pencil screenshots. If
    // Brent ever exports tokens from the file we should replace these with
    // the exported values verbatim.
    enum color {
        /// Saturated indigo used for selected states, primary buttons,
        /// toggle on-state, tab-bar active pill.
        static let primary = Color(red: 0.42, green: 0.36, blue: 0.91)   // ~#6B5CE8

        /// Slightly darker shade used for pressed/active backgrounds.
        static let primaryPressed = Color(red: 0.36, green: 0.30, blue: 0.84)

        /// Very light lavender used as the fill of the icon chips behind
        /// each menu row icon (Settings, Device Control quick-presets, etc).
        static let iconChipFill = Color(red: 0.93, green: 0.92, blue: 1.00)

        /// Dark purple used for the glyph inside an icon chip.
        static let iconChipGlyph = Color(red: 0.36, green: 0.30, blue: 0.84)

        /// Page background — not pure white so white cards still have
        /// contrast. Matches the Pencil page fill.
        static let pageBackground = Color(red: 0.96, green: 0.97, blue: 0.99)

        /// Card fill. Pure white by design.
        static let cardFill = Color.white

        /// Primary title text color. Near-black, slight warmth so it
        /// reads less harsh than `.black`.
        static let title = Color(red: 0.07, green: 0.09, blue: 0.15)

        /// Secondary label (subtitles, counts, descriptions).
        static let subtitle = Color(red: 0.45, green: 0.48, blue: 0.55)

        /// Tertiary/muted label (placeholder text, very quiet metadata).
        static let muted = Color(red: 0.60, green: 0.63, blue: 0.70)

        /// Divider / hairline separator color.
        static let divider = Color(red: 0.90, green: 0.91, blue: 0.94)

        /// Success / confirmation color — green banner used by toast
        /// messages ("Bedroom added to group") matching Pencil
        /// node `co524`. Sampled by eye from the Pencil screenshot
        /// (saturated emerald, not flat Apple green).
        static let success = Color(red: 0.19, green: 0.74, blue: 0.54)  // ~#30BC8A

        /// Danger / error color — red banner used by toast messages
        /// ("Kitchen disconnected") matching Pencil `pyUlJ`, also
        /// the offline subtitle color in the room picker sheet.
        static let danger = Color(red: 0.93, green: 0.32, blue: 0.30)   // ~#ED514C
    }

    // MARK: Radii
    //
    // The Pencil file uses two card radii: the large ~20pt radius for
    // top-level cards (weather card, room cards, device rows) and a smaller
    // ~12pt radius for inline controls (icon chips, chips in general).
    enum radius {
        static let chip: CGFloat = 12
        static let card: CGFloat = 20
        static let pill: CGFloat = 28
    }

    // MARK: Spacing
    //
    // A handful of named insets so cards don't drift off a consistent grid.
    enum space {
        static let cardPadding: CGFloat = 16
        static let cardGap: CGFloat = 12
        static let sectionGap: CGFloat = 24
        static let screenHorizontal: CGFloat = 20
    }

    // MARK: Typography
    //
    // Matches the Pencil file's type ramp. We don't ship a custom font yet;
    // these map onto system fonts with weight/size overrides.
    enum font {
        static let screenTitle = Font.system(size: 28, weight: .bold)
        static let sectionHeader = Font.system(size: 20, weight: .semibold)
        static let cardTitle = Font.system(size: 16, weight: .semibold)
        static let cardSubtitle = Font.system(size: 13, weight: .regular)
        static let tabLabel = Font.system(size: 11, weight: .medium)
    }
}

// MARK: - Card modifier
//
// `.hcCard()` wraps a view in the standard Pencil card treatment: white
// fill, 20pt rounded corners, soft drop shadow, 16pt internal padding.
// Used literally everywhere — room tiles, scene tiles, device rows,
// settings rows, weather card.

extension View {
    /// Standard Pencil card: white rounded rect + soft shadow + padding.
    /// Pass `padding: 0` when the child view manages its own padding.
    func hcCard(padding: CGFloat = Theme.space.cardPadding) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(Theme.color.cardFill)
                    .shadow(color: Color.black.opacity(0.06),
                            radius: 10, x: 0, y: 4)
            )
    }
}

// MARK: - Icon chip
//
// Small square background + centered SF Symbol glyph. Used as the leading
// element of every Settings row, every Add Device category, every device
// card row, and next to section headers on the Home Dashboard. The Pencil
// file's icon chips are filled with a very light lavender; the glyph is a
// dark, saturated purple. Don't tint these with `.accentColor` — they're
// a brand element and need to read the same everywhere.

struct IconChip: View {
    let systemName: String
    var size: CGFloat = 40
    var fill: Color = Theme.color.iconChipFill
    var glyph: Color = Theme.color.iconChipGlyph

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(glyph)
            )
    }
}

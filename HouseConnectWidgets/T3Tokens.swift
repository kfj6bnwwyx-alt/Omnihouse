//
//  T3Tokens.swift
//  HouseConnectWidgets
//
//  Pared-down T3/Braun-Swiss design tokens for the widget extension.
//  This is a subset of the main-app `Core/UI/T3Theme.swift` — only the
//  tokens widget views actually need. The Widget target is a separate
//  FSSG root (HouseConnectWidgets/) and does NOT see the main app's
//  sources, so we duplicate the minimum surface here.
//
//  Keep colors/fonts in lock-step with T3Theme.swift. If you change a
//  hex value there, mirror it here (and vice-versa).
//

import SwiftUI

enum T3 {
    // Colors — mirror T3Theme.swift
    static let page   = Color(hex: 0xF2F1ED)
    static let panel  = Color.white
    static let ink    = Color(hex: 0x0E0E0D)
    static let sub    = Color(hex: 0x6E6C66)
    static let rule   = Color(hex: 0xD9D7D0)
    static let accent = Color(hex: 0xE7591A)
    static let danger = Color(hex: 0xC54033)
    static let ok     = Color(hex: 0x4A8F5C)

    /// Inter Tight at a given size/weight. Falls back to the system
    /// font if Inter Tight is not registered with the widget extension
    /// (widgets share the app's bundled fonts via Info.plist).
    static func inter(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("Inter Tight", size: size).weight(weight)
    }

    /// IBM Plex Mono caption — uppercase + tracked in the label primitive.
    static func mono(_ size: CGFloat = 10) -> Font {
        .custom("IBM Plex Mono", size: size)
    }
}

/// Mono uppercase caption — used for timestamps, mode labels, etc.
struct TLabel: View {
    let text: String
    var color: Color = T3.sub

    var body: some View {
        Text(text)
            .font(T3.mono())
            .foregroundStyle(color)
            .tracking(1.6)
            .textCase(.uppercase)
    }
}

/// 1px hairline divider.
struct TRule: View {
    var body: some View {
        Rectangle()
            .fill(T3.rule)
            .frame(height: 1)
    }
}

/// Orange accent dot — the signature T3 mark.
struct TDot: View {
    var size: CGFloat = 8
    var color: Color = T3.accent

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

//
//  T3Theme.swift
//  house connect
//
//  T3 direction — Braun T3 pocket radio meets Dieter Rams.
//  Cream background, jet-black text, ONE orange accent dot.
//  Pure grid, tiny all-caps mono labels, generous whitespace,
//  functional iconography, tabular numerals in Inter Tight.
//
//  Design tokens from the Claude Design handoff (Swiss variant).
//  This file defines the complete design system for the T3 aesthetic.
//

import SwiftUI

// MARK: - T3 Design Tokens

enum T3 {
    // MARK: Colors
    static let page   = Color(hex: 0xF2F1ED)  // warm cream — primary background
    static let panel  = Color.white             // cards, tab bar
    static let ink    = Color(hex: 0x0E0E0D)   // primary text, on-state track
    static let sub    = Color(hex: 0x6E6C66)   // secondary text, inactive — darkened 2026-04-18 from 0x86847E (3.1:1) to meet WCAG AA body contrast (~4.5:1) against T3.page
    static let rule   = Color(hex: 0xD9D7D0)   // hairline dividers
    static let accent = Color(hex: 0xE7591A)   // Braun orange — single restrained accent

    // Severity — reserved for connection/diagnostic/error states.
    // Not for primary controls. Use sparingly.
    static let danger = Color(hex: 0xC54033)   // red — "can't reach", auth failure
    static let ok     = Color(hex: 0x4A8F5C)   // green — "connected"

    // MARK: Typography

    /// Display / UI font: Inter Tight
    static let display = Font.custom("Inter Tight", size: 15)

    /// Mono caption: IBM Plex Mono — 10px, uppercase, wide tracking
    static func mono(_ size: CGFloat = 10) -> Font {
        .custom("IBM Plex Mono", size: size)
    }

    /// Inter Tight at a specific size/weight
    static func inter(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("Inter Tight", size: size).weight(weight)
    }

    // MARK: Spacing
    static let screenPadding: CGFloat = 24
    static let sectionTopPad: CGFloat = 18
    static let sectionBottomPad: CGFloat = 8
    static let rowVerticalPad: CGFloat = 14

    /// Risk-tiered long-press durations. Higher risk = longer hold.
    enum LongPress {
        static let light: Double = 0.4     // reversible (lock unlock)
        static let medium: Double = 0.5    // adjustment (thermostat step)
        static let heavy: Double = 0.6     // destructive / emergency (silence alarm)
    }

    // MARK: Radii
    static let pillRadius: CGFloat = 999
    static let tabBarRadius: CGFloat = 14
    static let segmentRadius: CGFloat = 8
    static let segmentCellRadius: CGFloat = 6
    // Cards/rows: NO rounding — rely on hairlines

    // MARK: Shadows
    static let tabBarShadow: Color = .black.opacity(0.03)

    // MARK: Stroke
    static let iconStroke: CGFloat = 1.4
    static let activeIconStroke: CGFloat = 1.7
}

// MARK: - T3 Primitives

/// Mono uppercase caption — the workhorse label of the T3 system.
/// Used for timestamps, provider names, indices, state strings.
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

/// 1px hairline divider in the rule color.
struct TRule: View {
    var body: some View {
        Rectangle()
            .fill(T3.rule)
            .frame(height: 1)
    }
}

/// Inline orange dot — the signature T3 accent mark.
/// Used for active indicators, status dots, the splash power dot.
struct TDot: View {
    var size: CGFloat = 8
    var color: Color = T3.accent

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Screen header with back chevron + left label / right label
struct THeader: View {
    let backLabel: String
    var rightLabel: String? = nil
    var showDot: Bool = false
    var onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    T3IconImage(systemName: "chevron.left")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.ink)
                    TLabel(text: backLabel, color: T3.ink)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if let right = rightLabel {
                HStack(spacing: 6) {
                    if showDot { TDot(size: 6) }
                    TLabel(text: right)
                }
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 8)
    }
}

/// Screen title block — eyebrow dot + big title + subtitle
struct TTitle: View {
    let title: String
    var subtitle: String? = nil
    var isActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isActive {
                HStack(spacing: 10) {
                    TDot(size: 8)
                    TLabel(text: "Active")
                }
                .padding(.bottom, 6)
            }

            Text(title)
                .font(T3.inter(42, weight: .medium))
                .tracking(-1.4)
                .foregroundStyle(T3.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let sub = subtitle {
                Text(sub)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }
}

/// Section header — title + trailing mono count
struct TSectionHead: View {
    let title: String
    var count: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            if let count {
                TLabel(text: count)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, T3.sectionTopPad)
        .padding(.bottom, T3.sectionBottomPad)
    }
}

/// Animated pill toggle — ON = ink track + orange knob
struct TPill: View {
    @Binding var isOn: Bool
    var size: CGSize = CGSize(width: 40, height: 22)

    var body: some View {
        Button {
            withAnimation(.linear(duration: 0.15)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? T3.ink : T3.rule)
                    .frame(width: size.width, height: size.height)

                Circle()
                    .fill(isOn ? T3.accent : .white)
                    .frame(width: size.height - 4, height: size.height - 4)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen top chrome

/// Canonical top-chrome spacer for tab-root screens (no back chevron, no
/// nav bar content). Matches the vertical space consumed by `THeader`
/// on stack-pushed screens so that the first `TTitle` in every view
/// lands at the same y-coordinate.
///
/// Spec (2026-04-18): THeader band ≈ 32pt (8 top + icon row + 8 bottom)
/// + `TTitle` padding.top 22 → title lands ~54pt below the safe-area
/// inset. Tab roots have no THeader, so we pad the content by 32pt
/// before the title block to match.
struct T3ScreenTopPad: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.top, 32)
    }
}

extension View {
    /// Apply on the outer container of a tab-root screen (no back
    /// chevron, no nav bar). Locks the primary `TTitle` to the same
    /// vertical position as stack-pushed screens.
    func t3ScreenTopPad() -> some View {
        modifier(T3ScreenTopPad())
    }
}

// MARK: - Color hex init

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

// MARK: - Shimmer modifier

/// T3 skeleton loading shimmer — subtle opacity pulse.
struct ShimmerModifier: ViewModifier {
    @State private var phase: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(phase ? 0.4 : 0.15)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: phase)
            .onAppear { phase = true }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Sheet chrome

/// Replaces the default sheet material with a T3 cream panel and
/// an ink-tinted scrim behind it, so presented sheets read as T3
/// instead of system gray. iOS 16.4+ only — falls through silently
/// on older OS versions. Pair with `.sheet { Content().modifier(T3SheetChromeModifier()) }`.
struct T3SheetChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationBackground(T3.page)
        } else {
            content
        }
    }
}

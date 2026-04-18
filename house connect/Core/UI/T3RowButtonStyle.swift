//
//  T3RowButtonStyle.swift
//  house connect
//
//  Press-state feedback for tappable rows in the T3 aesthetic.
//  Row background cross-fades to T3.rule at 0.4 opacity on press
//  (120ms ease-out) and eases back to clear on release (180ms).
//  Honors prefers-reduced-motion.
//

import SwiftUI

/// Applies T3 pressed-state feedback to tappable rows.
/// Behavior: row background cross-fades to T3.rule at 0.4 opacity over 120ms
/// on press, eases back to clear on release. Respects reduce-motion.
struct T3RowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                T3.rule
                    .opacity(configuration.isPressed ? 0.4 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeOut(duration: configuration.isPressed ? 0.08 : 0.18),
                        value: configuration.isPressed
                    )
            )
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == T3RowButtonStyle {
    static var t3Row: T3RowButtonStyle { T3RowButtonStyle() }
}

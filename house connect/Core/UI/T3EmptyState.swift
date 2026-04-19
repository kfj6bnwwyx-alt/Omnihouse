//
//  T3EmptyState.swift
//  house connect
//
//  Reusable "nothing here yet" surface for T3 tab roots.
//
//  Design intent — refined Swiss minimal:
//    - Centered in its container with generous vertical padding so the
//      block lands near optical center rather than top-heavy.
//    - Optional 32pt icon in T3.sub (no chip, no gradient, no shadow).
//    - Title in T3.ink, subtitle in T3.sub, clamped to ~280pt wide for
//      reading comfort.
//    - Optional action rendered as an outlined ghost button (thin rule
//      stroke, ink label) — avoids the filled marketing-style CTA used
//      in the legacy `EmptyStateCard`.
//
//  Used by T3RoomsTabView, T3DevicesTabView and T3NotificationsView to
//  stop those surfaces rendering as blank whitespace when the registry
//  returns zero items.
//

import SwiftUI

struct T3EmptyState: View {
    let iconSystemName: String?
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        iconSystemName: String? = nil,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            if let iconSystemName {
                T3IconImage(systemName: iconSystemName)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(T3.sub)
            }

            Text(title)
                .font(T3.inter(22, weight: .medium))
                .tracking(-0.4)
                .foregroundStyle(T3.ink)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(T3.inter(13, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle()
                                .stroke(T3.rule, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 72)
    }
}

#Preview("Icon + title") {
    T3EmptyState(
        iconSystemName: "sofa.fill",
        title: "No rooms yet"
    )
    .background(T3.page)
}

#Preview("Icon + title + subtitle") {
    T3EmptyState(
        iconSystemName: "bell",
        title: "All caught up",
        subtitle: "New alerts and events will appear here."
    )
    .background(T3.page)
}

#Preview("Full with action") {
    T3EmptyState(
        iconSystemName: "server",
        title: "No devices connected",
        subtitle: "Connect Home Assistant in Settings to see your devices here.",
        actionTitle: "Open Settings",
        action: {}
    )
    .background(T3.page)
}

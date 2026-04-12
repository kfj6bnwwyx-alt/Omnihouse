//
//  SettingsSubpageHeader.swift
//  house connect
//
//  Shared header for Settings sub-pages (About, Help, Notifications,
//  Appearance, etc.). Provides a back button + title + subtitle, matching
//  the DeviceDetailHeader pattern used on device screens. Needed because
//  all our views hide the system navigation bar to use custom chrome,
//  so pushed views must supply their own back affordance.
//

import SwiftUI

struct SettingsSubpageHeader: View {
    let title: String
    let subtitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.chip,
                                         style: .continuous)
                            .fill(Theme.color.cardFill)
                            .shadow(color: .black.opacity(0.05),
                                    radius: 6, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font.screenTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }
}

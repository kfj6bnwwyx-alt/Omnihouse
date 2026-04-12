//
//  DeviceDetailHeader.swift
//  house connect
//
//  Shared chrome for every bespoke device-detail screen. The Pencil design
//  uses the same top bar on the Sonos, Thermostat, Camera, and Smoke Alarm
//  screens: a back button in the leading slot, a centered title + small
//  room subtitle, and (when the device has a power capability) a purple
//  pill toggle in the trailing slot.
//
//  We mount this inside the scroll view, NOT as a toolbar, because the
//  Pencil comps place it flush with the page content and use custom
//  typography. The parent view is responsible for hiding the system nav
//  bar (`.toolbar(.hidden, for: .navigationBar)` or by handing back
//  navigation off to the header's own back button).
//

import SwiftUI

struct DeviceDetailHeader: View {
    let title: String
    let subtitle: String?
    /// `nil` means "this device has no power capability" → hide the pill.
    let isOn: Bool?
    /// Tapped when the user toggles the pill. Ignored when `isOn == nil`.
    let onTogglePower: (Bool) -> Void

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
                    .font(Theme.font.sectionHeader)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            if let isOn {
                PowerPill(isOn: isOn, onToggle: onTogglePower)
            }
        }
    }
}

/// The purple pill toggle the Pencil design uses in the upper-right of
/// every device screen. Filled purple + white "ON" text when live,
/// light gray + "OFF" when off. We use a custom shape instead of
/// SwiftUI's `Toggle` so we can match the exact geometry from the comps.
private struct PowerPill: View {
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isOn)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .bold))
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(isOn ? Color.white : Theme.color.subtitle)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOn ? Theme.color.primary : Theme.color.iconChipFill)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Power")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(isOn ? "Double-tap to turn off" : "Double-tap to turn on")
        .accessibilityAddTraits(.isButton)
    }
}

//
//  DeviceDetailHeader.swift
//  house connect
//
//  Shared chrome for legacy device-detail screens. T3 views use THeader
//  instead; this component remains for any views not yet migrated.
//  Converted to T3/Swiss tokens — flat back chevron, T3.inter typography,
//  T3.accent power pill, no rounded cards or shadows.
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
                T3IconImage(systemName: "chevron.left")
                    .frame(width: 14, height: 14)
                    .foregroundStyle(T3.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(T3.inter(16, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    TLabel(text: subtitle.uppercased())
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
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
    }
}

/// T3-styled power pill for the legacy header — orange fill when on,
/// rule-bordered outline when off. Matches the T3 accent palette.
private struct PowerPill: View {
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isOn)
        } label: {
            HStack(spacing: 5) {
                T3IconImage(systemName: "power")
                    .frame(width: 10, height: 10)
                Text(isOn ? "ON" : "OFF")
                    .font(T3.mono(10))
                    .tracking(1.4)
            }
            .foregroundStyle(isOn ? T3.page : T3.sub)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isOn ? T3.ink : T3.page)
            .overlay(
                Rectangle().stroke(isOn ? Color.clear : T3.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Power")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(isOn ? "Double-tap to turn off" : "Double-tap to turn on")
        .accessibilityAddTraits(.isButton)
    }
}

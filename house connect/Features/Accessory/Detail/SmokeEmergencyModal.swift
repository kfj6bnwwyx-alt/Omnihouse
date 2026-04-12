//
//  SmokeEmergencyModal.swift
//  house connect
//
//  Full-screen emergency modal for active smoke alerts (Pencil `RAISW`).
//  Presented via `.fullScreenCover(item:)` on `RootTabView`, bound to
//  `SmokeAlertController.activeAlertContext`. Blankets the UI the
//  instant a smoke alert is raised — complements the Live Activity
//  pipeline but does NOT depend on it (Live Activities may be
//  disabled in Settings).
//
//  Layout matches Pencil `RAISW`:
//    - Top half: red fill, big warning glyph, "Smoke Detected!" title,
//      "<Room> · <Device>" subtitle, "Today, <h:mm a>" timestamp.
//    - Bottom half: white card with numbered "Emergency Instructions"
//      list, then two CTAs:
//        · "Call Emergency Services" — primary red, opens `tel:911`.
//        · "Silence Alarm"           — outline red, calls acknowledge().
//
//  Safety posture:
//    - Dismissing via swipe-down is intentionally allowed (SwiftUI
//      fullScreenCover default) — the Live Activity + haptics keep
//      running until the user explicitly acknowledges. We only clear
//      `activeAlertContext` on Silence / dismiss, never on cover-drop
//      from the system (the OS doesn't invoke onDismiss in those
//      cases on this layer).
//    - Tapping "Call Emergency Services" uses `UIApplication.open(tel:)`.
//      We don't auto-dial; iOS still shows a confirmation sheet. Not
//      acknowledging until after the call UI returns is deliberate —
//      if the user bails mid-dial, the alert stays up.
//

#if os(iOS)

import SwiftUI
import UIKit

struct SmokeEmergencyModal: View {
    let context: SmokeEmergencyContext

    /// Fired when the user taps "Silence Alarm". Parent wires this to
    /// `SmokeAlertController.acknowledge()`, which flips the state on
    /// any in-flight Live Activity AND clears `activeAlertContext`,
    /// which in turn drops this modal.
    let onSilence: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            redHero
            instructionsSection
        }
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - Red hero

    /// Top half of the screen. Full-bleed red background with the
    /// warning triangle, title, subtitle, and timestamp.
    private var redHero: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 20)
                .accessibilityHidden(true)
            Text("Smoke Detected!")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            Text(subtitleLine)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            Text(timestampLine)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(emergencyRed.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Smoke Detected, \(subtitleLine), \(timestampLine)")
    }

    /// "Living Room · Nest Protect" when a room is available,
    /// otherwise just the device name.
    private var subtitleLine: String {
        if let room = context.roomName, !room.isEmpty {
            return "\(room) · \(context.deviceName)"
        }
        return context.deviceName
    }

    /// "Today, 2:47 PM" — the Pencil copy.
    private var timestampLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Today, \(formatter.string(from: context.triggeredAt))"
    }

    // MARK: - Instructions + CTAs

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Emergency Instructions")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.color.title)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(
                    number: 1,
                    text: "Get everyone out of the house immediately"
                )
                instructionRow(
                    number: 2,
                    text: "Call 911 or emergency services"
                )
                instructionRow(
                    number: 3,
                    text: "Do not re-enter until cleared by fire dept."
                )
            }

            Spacer(minLength: 16)

            callEmergencyButton
            silenceButton
        }
        .padding(.horizontal, Theme.space.screenHorizontal)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Numbered red circle + instruction text. Matches the Pencil rows.
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(emergencyRed)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.color.title)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }

    private var callEmergencyButton: some View {
        Button {
            // iOS still shows its own dial-confirmation sheet — we're
            // not forcing a call, just surfacing it one tap away.
            if let url = URL(string: "tel://911") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Call Emergency Services")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(emergencyRed)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call 911")
        .accessibilityHint("Double-tap to call emergency services. iOS will confirm before dialing.")
    }

    private var silenceButton: some View {
        Button(action: onSilence) {
            HStack(spacing: 8) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Silence Alarm")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(emergencyRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(emergencyRed, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Silence Alarm")
        .accessibilityHint("Double-tap to silence the smoke alarm and dismiss this alert")
    }

    // MARK: - Color

    /// The Pencil emergency red. Doesn't live in `Theme.color` because
    /// it's only used here — if we reuse it elsewhere (e.g. a CO
    /// alert variant), promote it then.
    private var emergencyRed: Color {
        Color(red: 0.93, green: 0.29, blue: 0.27)  // ~#EE4A45
    }
}

#endif  // os(iOS)

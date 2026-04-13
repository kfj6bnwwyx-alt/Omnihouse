//
//  SmokeAlarmAlertView.swift
//  house connect
//
//  Pencil `RAISW` — Full-screen emergency alert shown when a smoke or
//  CO alarm triggers. Designed as a standalone view with explicit
//  parameters (unlike SmokeEmergencyModal which takes a context object).
//  Can be presented via NavigationStack push or fullScreenCover.
//

import SwiftUI

struct SmokeAlarmAlertView: View {
    let roomName: String
    let deviceName: String
    let detectedAt: Date

    let onSilence: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            dangerHero
            bottomSection
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Danger hero (top ~40%)

    private var dangerHero: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 24)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text("Smoke Detected!")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(.white)

            Text("\(roomName) \u{00B7} \(deviceName)")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.80))

            Text(formattedTimestamp)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.60))

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: UIScreen.main.bounds.height * 0.40)
        .background(Theme.color.danger.ignoresSafeArea(edges: .top))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Emergency: Smoke Detected in \(roomName). \(deviceName), \(formattedTimestamp)")
        .accessibilityAddTraits(.isHeader)
    }

    /// Cached formatter — avoids allocating on every render.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var formattedTimestamp: String {
        "Today, \(Self.timeFormatter.string(from: detectedAt))"
    }

    // MARK: - Bottom section

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                .padding(.bottom, 12)
            silenceButton
        }
        .padding(.horizontal, Theme.space.screenHorizontal)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.radius.card,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Theme.radius.card
            )
            .fill(Theme.color.cardFill)
            .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: -Theme.radius.card)
    }

    // MARK: - Instruction row

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.danger)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
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

    // MARK: - Buttons

    private var callEmergencyButton: some View {
        Button {
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
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.color.danger)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call 911")
        .accessibilityHint("Dials emergency services immediately")
        .accessibilityAddTraits(.isButton)
    }

    private var silenceButton: some View {
        Button {
            onSilence()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Silence Alarm")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.color.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.color.danger, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Silence Alarm")
        .accessibilityHint("Silences the smoke alarm on \(deviceName). Does not cancel the emergency.")
        .accessibilityAddTraits(.isButton)
    }
}

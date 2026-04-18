//
//  T3SmokeAlarmAlertView.swift
//  house connect
//
//  T3 emergency treatment for the full-screen smoke-alarm alert.
//  Presented via `fullScreenCover` from `T3RootView` when
//  `SmokeAlertController.activeAlertContext` becomes non-nil.
//
//  Design deviation: this is the ONE screen that breaks the T3
//  cream-page rule. Full-bleed `T3.danger` red is intentional — a
//  real fire alarm overrides aesthetic restraint. Content reads as
//  cream on red; no pulsing, no animation. reduceMotion is
//  respected by suppressing the elapsed-time timer ticking
//  animation hooks (timer itself still fires — the number is the
//  information).
//
//  Emergency rules:
//    * No auto-dismiss. User must acknowledge (Silence / Dismiss).
//    * Heavy warning haptic on every button tap.
//    * Timer shows elapsed time since detection, tabular numerals.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

struct T3SmokeAlarmAlertView: View {
    let roomName: String
    let deviceName: String
    let detectedAt: Date

    let onSilence: () -> Void
    let onDismiss: () -> Void

    @State private var now: Date = Date()

    // Tick the elapsed-time display every second. Timer is not an
    // animation — reduceMotion does not suppress it (the number
    // itself is the information the user needs).
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Top caption: SMOKE DETECTED · elapsed
            Text("SMOKE DETECTED \u{00B7} \(elapsedString)")
                .font(T3.mono(11))
                .monospacedDigit()
                .tracking(2.0)
                .foregroundStyle(T3.page)
                .padding(.top, 24)

            Spacer(minLength: 24)

            // Giant flame glyph — static
            T3IconImage(systemName: "flame")
                .frame(width: 72, height: 72)
                .foregroundStyle(T3.page)
                .accessibilityHidden(true)

            // Room + device
            VStack(spacing: 6) {
                Text(roomName)
                    .font(.custom("Inter Tight", size: 32).weight(.bold))
                    .foregroundStyle(T3.page)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(deviceName)
                    .font(.custom("Inter Tight", size: 18).weight(.regular))
                    .foregroundStyle(T3.page.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.top, 20)
            .padding(.horizontal, T3.screenPadding)

            Text("DETECTED \(detectedTimeString)")
                .font(T3.mono(10))
                .tracking(1.6)
                .foregroundStyle(T3.page.opacity(0.70))
                .padding(.top, 14)

            Spacer(minLength: 0)

            // Bottom: two 56pt buttons, 1pt spacing
            HStack(spacing: 1) {
                silenceButton
                dismissButton
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T3.danger.ignoresSafeArea())
        .onReceive(timer) { value in
            now = value
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Emergency: smoke detected in \(roomName), \(deviceName). Detected at \(detectedTimeString)."
        )
    }

    // MARK: - Buttons

    private var silenceButton: some View {
        Button(action: fireHaptic(onSilence)) {
            Text("SILENCE")
                .font(.custom("Inter Tight", size: 15).weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(T3.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(T3.page)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Silence alarm")
        .accessibilityHint("Silences the smoke alarm. Does not cancel the emergency.")
    }

    private var dismissButton: some View {
        Button(action: fireHaptic(onDismiss)) {
            Text("DISMISS")
                .font(.custom("Inter Tight", size: 15).weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(T3.page)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(T3.danger)
                .overlay(
                    Rectangle().strokeBorder(T3.page, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss alert")
    }

    private func fireHaptic(_ action: @escaping () -> Void) -> () -> Void {
        {
            #if os(iOS)
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.warning)
            #endif
            action()
        }
    }

    // MARK: - Formatters

    private var elapsedString: String {
        let secs = max(0, Int(now.timeIntervalSince(detectedAt)))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }

    private static let detectedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var detectedTimeString: String {
        Self.detectedFormatter.string(from: detectedAt).uppercased()
    }
}

#if DEBUG
#Preview {
    T3SmokeAlarmAlertView(
        roomName: "Kitchen",
        deviceName: "First Alert Smoke Detector",
        detectedAt: Date().addingTimeInterval(-42),
        onSilence: {},
        onDismiss: {}
    )
}
#endif

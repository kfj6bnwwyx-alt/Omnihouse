//
//  T3SplashView.swift
//  house connect
//
//  T3/Swiss splash screen — Braun T3 power-dot + tight logotype.
//  Minimal: orange dot, "house connect." wordmark, loading progress.
//  Matches the Claude Design handoff (T3Splash component).
//
//  Error state (2026-04-18): RootContainerView races `startAll()`
//  against a 30s ceiling. If the ceiling wins, the container flips
//  `showError = true` and we render the error panel in place of the
//  progress ticks. Retry and "Continue to app" actions are passed in
//  as closures — we don't own the registry or navigator here.
//

import SwiftUI

struct T3SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var progress: Int = 0
    private let total = 10

    /// When true, swap the progress row for an error panel with Retry +
    /// Continue actions. Owned by `RootContainerView`.
    var showError: Bool = false

    /// Tapped in the error state. Container re-awaits `startAll()` and
    /// flips `showError` back off while it runs.
    var onRetry: (() -> Void)? = nil

    /// Tapped in the error state. Container flips `isReady = true` so the
    /// user can reach Settings and fix the connection. Labelled
    /// "Continue to app" rather than "Go to Settings" because the splash
    /// can't reach into `T3RootView`'s navigator from here — once the
    /// user is in the app they can tap the Settings tab themselves.
    var onContinue: (() -> Void)? = nil

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            VStack {
                // Top meta row
                HStack {
                    TLabel(text: "House Connect")
                    Spacer()
                    TLabel(text: "V 1.0")
                }

                Spacer()

                // Centerpiece: orange power dot + logotype
                VStack(alignment: .leading, spacing: 0) {
                    TDot(size: 16)

                    Text("house\nconnect.")
                        .font(T3.inter(44, weight: .medium))
                        .tracking(-1.4)
                        .lineSpacing(0)
                        .foregroundStyle(T3.ink)
                        .padding(.top, 22)

                    Text("A calm controller for everything at home.\nSeventeen devices, six rooms.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(4)
                        .padding(.top, 14)
                        .frame(maxWidth: 240, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Bottom: progress ticks while loading, error panel on timeout.
                if showError {
                    errorPanel
                } else {
                    progressPanel
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 46)
        }
        .onAppear {
            // Animate progress ticks — skipped in reduced-motion mode,
            // where we jump straight to the full bar so nothing moves.
            if reduceMotion {
                progress = total
                return
            }
            for i in 1...total {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    progress = i
                }
            }
        }
    }

    // MARK: - Sub-panels

    /// Normal loading state — tick progress bar.
    private var progressPanel: some View {
        VStack(spacing: 10) {
            TRule()

            HStack {
                TLabel(text: "Loading")
                Spacer()

                HStack(spacing: 3) {
                    ForEach(0..<total, id: \.self) { i in
                        Rectangle()
                            .fill(i < progress ? T3.ink : T3.rule)
                            .frame(width: 6, height: 2)
                    }
                }

                Spacer()

                TLabel(text: String(format: "%02d / %02d", progress, total))
            }
        }
    }

    /// Error state — shown when provider startup exceeds the container
    /// timeout. Uses `T3.danger` for the eyebrow dot and ink/sub for
    /// text (matches EmptyState conventions) with two ghost buttons
    /// (Retry + Continue) borrowed from `T3EmptyState`.
    private var errorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            TRule()

            HStack(alignment: .top, spacing: 10) {
                // Danger eyebrow dot — same visual weight as TDot but
                // tinted red. Signals "something is wrong" without
                // shouting.
                Rectangle()
                    .fill(T3.danger)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't reach your providers")
                        .font(T3.inter(17, weight: .medium))
                        .tracking(-0.3)
                        .foregroundStyle(T3.ink)

                    Text("Startup timed out after 30 seconds. Check your Home Assistant URL and token, then try again.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                ghostButton(title: "Retry", action: { onRetry?() })
                ghostButton(title: "Continue to app", action: { onContinue?() })
                Spacer(minLength: 0)
            }
            .padding(.top, 6)
        }
    }

    /// Outlined ghost button — matches `T3EmptyState`'s action style so
    /// the splash's error escape feels consistent with the rest of the
    /// app's empty/error surfaces.
    private func ghostButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
    }
}

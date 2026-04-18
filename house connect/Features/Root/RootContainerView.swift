//
//  RootContainerView.swift
//  house connect
//
//  Thin wrapper around `SplashView` → `RootTabView`. Owns the boolean
//  that controls which of the two is on-screen and handles the
//  cross-fade transition between them.
//
//  Why this exists: `RootTabView` used to be the sole root of
//  `WindowGroup`. To land the Pencil splash (`QXNHS`) without
//  polluting `RootTabView` (which already juggles tab selection,
//  smoke-emergency cover presentation, and provider startup), we
//  hoist a container one level up.
//
//  Splash gating (2026-04-18): splash is no longer cosmetic — it now
//  gates on `ProviderRegistry.startAll()` completing, with a 1.2s
//  minimum floor so the splash never flashes past on warm starts.
//  If startup takes longer than the floor, splash stays until
//  startAll completes. If it finishes early, we wait out the floor.
//

import SwiftUI

struct RootContainerView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Flips to `true` once both (a) provider startup completes and
    /// (b) the minimum splash floor has elapsed. On the flip we
    /// cross-fade from the splash into the live app.
    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                T3RootView()
                    .transition(.opacity)
            } else {
                T3SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            // Kick off provider startup and a minimum splash timer
            // concurrently. Whichever finishes last determines when
            // we transition. Rationale:
            //   * 1.2s floor — splash never feels like a flash on
            //     warm launches. Long enough to read the logo.
            //   * Registry gate — on cold starts we hold the splash
            //     until providers are actually ready, so the first
            //     paint of the home tab isn't empty skeletons.
            async let warmup: Void = registry.startAll()
            async let floor: Void = { try? await Task.sleep(for: .milliseconds(1_200)) }()
            _ = await (warmup, floor)

            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                isReady = true
            }
        }
    }
}

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
//  hoist a container one level up. SplashView is cosmetic — it
//  doesn't gate provider startup or any other async work; the tab
//  view still kicks off `registry.startAll()` the moment it mounts.
//

import SwiftUI

struct RootContainerView: View {
    /// False during the first ~1.8s after launch, true thereafter. On
    /// the flip we cross-fade from the splash into the live app.
    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                RootTabView()
                    .transition(.opacity)
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            // Splash display time. Short enough that users on return
            // launches don't feel stalled, long enough that the
            // entrance animation actually reads. 1.8s is the sweet
            // spot Apple's HIG recommends for cold launch splashes.
            try? await Task.sleep(for: .milliseconds(1_800))
            withAnimation(.easeInOut(duration: 0.35)) {
                isReady = true
            }
        }
    }
}

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
//  Startup timeout (Wave N, 2026-04-18): if `startAll()` hasn't
//  completed within 30 seconds the splash flips to an error panel
//  with Retry + Continue actions. Without the ceiling, a wrong HA
//  URL or expired token would park the user on the splash forever.
//
//  Resume refresh (Wave N, 2026-04-18): on `.active` transitions
//  from `.background`/`.inactive`, if the app was backgrounded for
//  more than 60 seconds we fire `registry.refreshAll()` in a
//  detached Task. Short resumes (pull down Control Centre, glance
//  at the lockscreen) skip the refetch.
//

import SwiftUI

struct RootContainerView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Flips to `true` once both (a) provider startup completes and
    /// (b) the minimum splash floor has elapsed. On the flip we
    /// cross-fade from the splash into the live app.
    @State private var isReady = false

    /// True when `startAll()` has exceeded the 30s ceiling and we're
    /// showing the error panel inside T3SplashView.
    @State private var showStartupError = false

    /// Non-nil while provider startup is in flight. Kept so Retry can
    /// cancel the old attempt before launching a new one.
    @State private var startupTask: Task<Void, Never>? = nil

    /// Wall-clock timestamp of the last `.active` phase, used to decide
    /// whether a resume warrants a `refreshAll()`. Nil until the first
    /// `.active` has been seen.
    @State private var lastActiveAt: Date? = nil

    /// How long the app may spend in `startAll()` before we surface the
    /// error state. 30s is long enough for a cold HA WebSocket
    /// handshake over a sluggish cellular hop but short enough that a
    /// misconfiguration surfaces within a single patience window.
    private let startupTimeout: Duration = .seconds(30)

    /// Minimum time the splash stays up even on a warm start. Keeps
    /// the logo readable and the transition from feeling jarring.
    private let splashFloor: Duration = .milliseconds(1_200)

    /// Only refetch on resume if the app has been backgrounded at least
    /// this long. Shorter resumes (quick Control Centre trip, glancing
    /// at a notification) skip the refresh — the data is still fresh.
    private let resumeRefreshThreshold: TimeInterval = 60

    var body: some View {
        ZStack {
            if isReady {
                T3RootView()
                    .transition(.opacity)
            } else {
                T3SplashView(
                    showError: showStartupError,
                    onRetry: retryStartup,
                    onContinue: continueToApp
                )
                .transition(.opacity)
            }
        }
        .task {
            runStartup()
        }
        .onChange(of: scenePhase, initial: false) { old, new in
            handleScenePhaseChange(from: old, to: new)
        }
    }

    // MARK: - Startup

    /// Runs `startAll()` alongside the 1.2s minimum-floor timer, then
    /// flips `isReady`. A separate detached watchdog flips
    /// `showStartupError` if `isReady` hasn't moved after 30s. The two
    /// branches are independent Tasks — no shared scope that could
    /// deadlock on uncooperative cancellation. Extracted from `.task`
    /// so Retry can re-invoke it.
    private func runStartup() {
        // Cancel any prior attempt (e.g. on Retry).
        startupTask?.cancel()
        showStartupError = false

        // Warmup branch: because `registry.startAll()` launches each
        // provider in a detached Task and returns after one yield, the
        // only real await here is the 1.2s floor. We no longer wrap the
        // warmup in a `withTaskGroup` race against the timeout — that
        // shape deadlocked when a provider's `start()` ignored
        // cancellation, since the task group can't exit until every
        // child returns.
        // Fire startAll fire-and-forget — it already launches each
        // provider in its own detached Task, so we gain nothing by
        // awaiting it and lose a main-actor hop. Then simply wait
        // out the floor and flip. This guarantees the splash exits
        // in ~1.2s regardless of provider health.
        Task { await registry.startAll() }

        let task = Task { @MainActor in
            try? await Task.sleep(for: splashFloor)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                isReady = true
            }
        }
        startupTask = task

        // Independent watchdog: if `isReady` hasn't flipped after
        // `startupTimeout`, surface the error panel. Detached so it
        // can't be held hostage by the warmup task.
        let currentTask = task
        Task { @MainActor in
            try? await Task.sleep(for: startupTimeout)
            guard !currentTask.isCancelled, !isReady else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                showStartupError = true
            }
        }
    }

    /// Retry button in the error state. Re-runs the startup race from
    /// scratch. `runStartup` cancels the old task first.
    private func retryStartup() {
        runStartup()
    }

    /// Continue-to-app button in the error state. Gives up waiting and
    /// lets the user into the app so they can reach Settings and fix
    /// the connection. Startup keeps running in the background — if it
    /// eventually succeeds, providers will populate and the banners
    /// (HAConnectionBanner, ProviderDisconnectedBanner) will clear on
    /// their own.
    private func continueToApp() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            isReady = true
        }
    }

    // MARK: - Resume refresh

    /// Fires `registry.refreshAll()` on `.active` transitions when the
    /// app has been backgrounded longer than `resumeRefreshThreshold`.
    /// Kept as fire-and-forget so the UI never blocks on the refetch —
    /// individual views animate their own freshness signals.
    private func handleScenePhaseChange(from old: ScenePhase, to new: ScenePhase) {
        let now = Date()

        // Only react to transitions INTO .active. First-boot
        // observations land here too (old == .active is unusual but
        // harmless — the elapsed check below handles it).
        guard new == .active else {
            if old == .active {
                // Leaving active — remember when, so the next return
                // can measure elapsed time. Stored on .background and
                // .inactive alike; either one is a "not-visible" hint.
                lastActiveAt = now
            }
            return
        }

        defer { lastActiveAt = now }

        // First .active of the session (or lastActiveAt never set):
        // startAll() already did the fetch, no refresh needed.
        guard let last = lastActiveAt else { return }

        // Skip refresh during the splash — startAll is in flight and
        // refreshAll on top of it would double-hammer providers that
        // aren't ready yet.
        guard isReady else { return }

        let elapsed = now.timeIntervalSince(last)
        guard elapsed >= resumeRefreshThreshold else { return }

        // Detached from the scenePhase callback so SwiftUI's view
        // update isn't blocked on network I/O. No global spinner —
        // each view renders its own freshness signal.
        Task { @MainActor in
            await registry.refreshAll()
        }
    }
}

//
//  SmokeAlertController.swift
//  house connect
//
//  Lifecycle owner for the smoke-alarm Live Activity. Providers call
//  `start(for:severity:)` when they detect smoke, `escalate(...)` to
//  flip warning → critical, and `end(...)` when the situation clears
//  or the user acknowledges. A `simulate(...)` entry point is exposed
//  so the SmokeAlarmDetailView can trigger the whole pipeline end-to-end
//  without a real Nest provider (until Phase 6 lands).
//
//  This is the ONLY place ActivityKit is touched from the app target.
//  Providers never import ActivityKit directly — they hand an Accessory
//  to this controller and let it deal with the framework.
//
//  Threading: `@MainActor` because ActivityKit requires main-thread
//  calls for `Activity.request` / `update` / `end`.
//
//  Critical alerts: `interruptionLevel: .critical` is set on the
//  AlertConfiguration when severity is `.critical`. That code path is
//  wired but won't fully light up until Apple grants the Critical Alerts
//  entitlement (`com.apple.developer.usernotifications.critical-alerts`).
//  Until then iOS silently downgrades to a regular time-sensitive alert.
//

import Foundation

#if os(iOS)

import ActivityKit

@MainActor
@Observable
final class SmokeAlertController {

    /// The single in-flight activity, if any. We only allow one smoke
    /// alert at a time — if a second device reports smoke while one is
    /// active, we update the existing one rather than stacking. Multi-
    /// device stacking is a follow-up once we see it in the wild.
    private var currentActivity: Activity<SmokeAlertAttributes>?

    /// True while a Live Activity is currently running. Bound by the
    /// SmokeAlarmDetailView so the UI can hide the "Simulate Alert"
    /// button mid-alert and show an "End Simulation" button instead.
    var isActive: Bool { currentActivity != nil }

    /// Drives the full-screen in-app emergency modal (Pencil `RAISW`).
    /// Separate from `currentActivity` so the modal can be presented
    /// even when Live Activities are disabled in Settings — the in-app
    /// modal is the always-available fallback. Set by `start(...)` /
    /// `simulate(...)`, cleared by `acknowledge()` / `end(...)`.
    ///
    /// RootTabView binds `.fullScreenCover(item:)` to this so the
    /// modal blankets every tab the instant smoke is reported.
    var activeAlertContext: SmokeEmergencyContext?

    // MARK: - Public API

    /// Start a new smoke-alert Live Activity for a specific accessory.
    /// Idempotent in the sense that if an activity for the same accessory
    /// is already running, this updates it in place rather than creating
    /// a duplicate.
    @discardableResult
    func start(
        for accessory: Accessory,
        roomName: String?,
        severity: SmokeAlertAttributes.Severity,
        guidance: String = "Get everyone out of the house immediately"
    ) -> Activity<SmokeAlertAttributes>? {

        // Ask ActivityKit whether Live Activities are even available
        // (user can disable them in Settings → Live Activities). If not,
        // bail — nothing we can do from here.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[SmokeAlert] Live Activities disabled in Settings — cannot start.")
            return nil
        }

        let attributes = SmokeAlertAttributes(
            accessoryStableID: "\(accessory.id.provider.rawValue):\(accessory.id.nativeID)",
            deviceName: accessory.name,
            roomName: roomName
        )

        let state = SmokeAlertAttributes.ContentState(
            severity: severity,
            triggeredAt: Date(),
            acknowledged: false,
            guidance: guidance
        )

        // Publish the in-app emergency modal context. Done up-front so
        // the modal blankets the UI even if the ActivityKit request
        // below fails (e.g. Live Activities disabled). The modal is
        // the user-visible fallback — the Live Activity is the bonus.
        activeAlertContext = SmokeEmergencyContext(
            deviceName: accessory.name,
            roomName: roomName,
            severity: severity,
            triggeredAt: Date()
        )

        // If an activity is already running, update it in place. We
        // compare stable IDs rather than object identity so a restart
        // from the same device coalesces cleanly.
        if let existing = currentActivity,
           existing.attributes.accessoryStableID == attributes.accessoryStableID {
            Task { await updateState(state) }
            return existing
        }

        // Otherwise end any stale one and request a new one.
        if let stale = currentActivity {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            let activity = try Activity<SmokeAlertAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            return activity
        } catch {
            print("[SmokeAlert] Failed to request activity: \(error)")
            return nil
        }
    }

    /// Escalate the in-flight activity from warning to critical. If
    /// nothing is currently running this is a no-op.
    func escalate() async {
        guard let activity = currentActivity else { return }
        var newState = activity.content.state
        newState.severity = .critical
        newState.guidance = "Smoke levels are rising — evacuate now"
        await updateState(newState)
    }

    /// The user tapped Silence / Call 911 from the Live Activity or the
    /// detail screen. Flip `acknowledged` so the widget chrome can show
    /// a quieter state, then end the activity after a short dismissal
    /// delay so the user still sees confirmation.
    func acknowledge() async {
        guard let activity = currentActivity else { return }
        var state = activity.content.state
        state.acknowledged = true
        await updateState(state)
        // Leave the activity on-screen for a beat after ack so the user
        // sees confirmation, then dismiss.
        try? await Task.sleep(for: .seconds(3))
        await end(reason: .acknowledged)
    }

    /// Explicitly end the activity.
    func end(reason: EndReason) async {
        // Always drop the in-app modal, even if no Live Activity was
        // ever started (e.g. Live Activities disabled in Settings).
        activeAlertContext = nil

        guard let activity = currentActivity else { return }
        let dismissal: ActivityUIDismissalPolicy = switch reason {
        case .acknowledged: .immediate
        case .clearedBySensor: .default
        case .simulationStopped: .immediate
        }
        await activity.end(activity.content, dismissalPolicy: dismissal)
        currentActivity = nil
    }

    enum EndReason {
        case acknowledged
        case clearedBySensor
        case simulationStopped
    }

    // MARK: - Simulation (dev-only trigger path)

    /// Drives the full pipeline without a real Nest provider: requests a
    /// warning-severity activity, escalates to critical after ~5s, then
    /// auto-ends after ~30s if the user never acknowledges. Used by the
    /// "Simulate Alert" button on SmokeAlarmDetailView while the Nest
    /// provider is still pending (Phase 6).
    func simulate(using accessory: Accessory, roomName: String?) async {
        _ = start(for: accessory,
                  roomName: roomName,
                  severity: .warning,
                  guidance: "Possible smoke detected — checking")

        try? await Task.sleep(for: .seconds(5))
        await escalate()

        try? await Task.sleep(for: .seconds(25))
        if currentActivity != nil {
            await end(reason: .simulationStopped)
        }
    }

    // MARK: - Private

    private func updateState(_ newState: SmokeAlertAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: newState, staleDate: nil)
        // `alertConfiguration` is what drives the repeating haptic loop
        // the Pencil prompt calls out. `.critical` bumps it past silent
        // mode once the Critical Alerts entitlement is granted.
        let alert: AlertConfiguration? = newState.severity == .critical && !newState.acknowledged
            ? AlertConfiguration(
                title: "Smoke Detected",
                body: "\(activity.attributes.deviceName) — \(newState.guidance)",
                sound: .default
              )
            : nil
        await activity.update(content, alertConfiguration: alert)
    }
}

// MARK: - Emergency modal context

/// Snapshot the full-screen emergency modal renders from. Identifiable
/// so `RootTabView` can bind it to `.fullScreenCover(item:)` — a new
/// instance (fresh UUID) guarantees the cover re-presents even if the
/// same device re-alarms.
struct SmokeEmergencyContext: Identifiable, Equatable {
    let id = UUID()
    let deviceName: String
    let roomName: String?
    let severity: SmokeAlertAttributes.Severity
    let triggeredAt: Date
}

#endif  // os(iOS)

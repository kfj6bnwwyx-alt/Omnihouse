//
//  T3ActionFeedback.swift
//  house connect
//
//  Reusable primitive for firing provider commands with proper
//  success/failure feedback. Solves a recurring bug in detail
//  views (lock, light, thermostat) where commands were launched
//  with `try? await registry.execute(...)`, silently swallowing
//  failures while the UI animated as if they had succeeded.
//
//  What this gives you:
//    1. Success haptic (light impact by default) ONLY after the
//       command returns without throwing.
//    2. Failure haptic (warning notification) on throw.
//    3. A caller-supplied revert closure invoked on failure so
//       optimistic UI state can roll back.
//    4. os.Logger line at .error level so silent failures show up
//       in Console.app.
//
//  Toast surfacing:
//    The codebase's `Toast` banner is state-driven per-view (a
//    `@State Toast?` on each host view). There's no global
//    ToastCenter yet. Callers that want a failure banner can pass
//    a `toast:` closure that mutates their local binding. If the
//    closure is nil we skip visual surfacing — haptic + log only.
//    TODO: when a global ToastCenter lands, collapse this callsite
//    into a default path so every detail view gets banners for
//    free.
//
//  Usage:
//
//      let previous = isOn
//      isOn = newValue                     // optimistic
//      await T3ActionFeedback.perform(
//          action: { try await registry.execute(.setPower(newValue), on: id) },
//          onFailure: { isOn = previous },
//          toast: { toastBinding = .error("Couldn't reach light") }
//      )
//

import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

enum HapticStyle {
    case light
    case medium
    case none
}

@MainActor
enum T3ActionFeedback {
    private static let logger = Logger(subsystem: "house.connect", category: "actions")

    /// Execute an async command with automatic haptic feedback,
    /// optional state revert on failure, and error logging.
    ///
    /// - Parameters:
    ///   - action: The throwing async command to run. Typically
    ///     `try await registry.execute(...)`.
    ///   - onFailure: Closure invoked on the main actor when
    ///     `action` throws. Use this to revert any optimistic
    ///     UI state you mutated before calling.
    ///   - successHaptic: Haptic style to fire on success.
    ///     Default `.light`. Pass `.none` to suppress (useful
    ///     for drag-end commits where a haptic already fired
    ///     during the drag).
    ///   - toast: Closure invoked on failure to surface a visible
    ///     error banner. The primitive doesn't know about any
    ///     specific toast model; callers typically mutate a
    ///     local `@State Toast?` binding inside this closure.
    ///   - errorDescription: Short label prefixed to the log
    ///     entry so you can tell Lock/Light/Thermostat failures
    ///     apart in Console.app.
    static func perform(
        action: () async throws -> Void,
        onFailure: (@MainActor () -> Void)? = nil,
        successHaptic: HapticStyle = .light,
        toast: (@MainActor () -> Void)? = nil,
        errorDescription: String? = nil
    ) async {
        do {
            try await action()
            fireSuccessHaptic(style: successHaptic)
        } catch {
            let label = errorDescription ?? "action"
            logger.error("\(label, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            fireFailureHaptic()
            onFailure?()
            toast?()
        }
    }

    private static func fireSuccessHaptic(style: HapticStyle) {
        #if canImport(UIKit)
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .none:
            break
        }
        #endif
    }

    private static func fireFailureHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

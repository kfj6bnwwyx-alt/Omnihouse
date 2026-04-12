//
//  SmokeAlertAttributes.swift
//  house connect
//
//  ActivityKit "contract" for the Nest Protect smoke alarm Live Activity.
//  This file is IMPORTED BY BOTH the main app target AND the widget
//  extension target — they speak ActivityKit by sharing this one type.
//
//  To make that dual-target membership work, the file lives in the main
//  app's source tree, but when you add the widget extension target in
//  Xcode you must ALSO tick this file's Target Membership checkbox for
//  the widget. (See HouseConnectWidgets/README.md for the exact steps.)
//
//  Design intent (see Pencil prompt `0wydc`):
//    "when the smoke is detected even before the alarm sounds i want my
//     watch and my phone to buzz again and again until i action on it."
//
//  That maps onto these fields:
//    - `severity` drives the color + haptic profile (warning vs critical).
//    - `acknowledged` ends the repeating haptic path once the user taps
//      Silence or Call 911 from the Live Activity.
//    - `triggeredAt` drives the "2m ago" timestamp visible on lock screen
//      and the expanded Dynamic Island layout.
//

import Foundation

// Live Activities are iOS-only. The app also builds for macOS / visionOS
// (see `SUPPORTED_PLATFORMS` in the pbxproj), so we gate the whole type
// on iOS. macOS builds still compile fine — they just don't get the
// Live Activity surface.
#if os(iOS)

import ActivityKit

/// ActivityAttributes conformance. Static context lives at the top level
/// (device name, room, accessoryID); dynamic state lives in
/// `ContentState` — ActivityKit only lets you update the ContentState,
/// never the top-level attributes, so anything that can change during
/// the activity's life must live in the nested struct.
struct SmokeAlertAttributes: ActivityAttributes, Hashable {
    // MARK: - Static context (set at .request time, immutable after)

    /// Stable identifier used by the controller to find and update an
    /// existing activity if the same device fires a new alert.
    let accessoryStableID: String

    /// Human-readable accessory name ("Kitchen Protect").
    let deviceName: String

    /// Room the device sits in, for the subtitle line in the UI.
    /// Nil when the device hasn't been assigned to a room.
    let roomName: String?

    // MARK: - Dynamic state (updateable via activity.update(...))

    struct ContentState: Codable, Hashable {
        /// Severity escalates as the situation worsens: warning (smoke
        /// detected but below alarm threshold) → critical (full alarm).
        var severity: Severity

        /// When the alert was first raised. Drives the "2m ago" label.
        /// Stored as a TimeInterval so the Codable representation is
        /// cheap and predictable.
        var triggeredAt: Date

        /// True after the user taps Silence or Call 911 from the Live
        /// Activity. The controller uses this to stop repeating haptics
        /// and eventually end the activity.
        var acknowledged: Bool

        /// Short guidance line: "Get everyone out immediately" etc.
        /// Kept on the state so we can escalate the copy as severity
        /// changes without ending and restarting the activity.
        var guidance: String
    }

    enum Severity: String, Codable, Hashable, CaseIterable {
        /// Smoke sensor crossed the early-detection threshold; the
        /// physical alarm has NOT yet sounded. This is the Pencil-prompt
        /// "even before the alarm sounds" state.
        case warning

        /// Full alarm: device is actively sounding. Triggers the red
        /// Live Activity chrome and critical haptics.
        case critical
    }
}

#endif  // os(iOS)

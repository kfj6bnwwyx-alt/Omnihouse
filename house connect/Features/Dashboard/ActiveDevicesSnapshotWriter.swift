//
//  ActiveDevicesSnapshotWriter.swift
//  house connect
//
//  App-side writer for the widget's shared-UserDefaults snapshot.
//  Keeps `HouseConnectWidgets/ActiveDevicesWidget.swift`'s
//  `SharedActiveDevicesSnapshot` suite in sync with whatever
//  `ActiveDevicesFilter` would produce right now.
//
//  No-op until the `group.house-connect.shared` App Group
//  capability is added to BOTH the app target and the widget
//  extension target (in Xcode → Signing & Capabilities). Until
//  then the widget falls back to placeholder data and this writer
//  silently skips. That's why it's safe to wire up the call site
//  before the entitlement work lands.
//
//  The snapshot struct is intentionally duplicated across the two
//  targets rather than shared via a framework — the shape is tiny
//  and narrow, and widget targets don't see the app's sources.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Mirror of `ActiveDevicesSnapshot` in the widget target. Kept in
/// lock-step here. See HouseConnectWidgets/ActiveDevicesWidget.swift.
private struct ActiveDevicesSnapshot: Codable {
    var lightsOn: Int
    var nowPlaying: Int
    var climateActive: Int
    var updatedAt: Date
}

enum ActiveDevicesSnapshotWriter {
    private static let suiteName = "group.house-connect.shared"
    private static let key = "activeDevicesSnapshot.v1"

    /// Computes the three counts from `ActiveDevicesFilter` and
    /// writes them to the shared suite. Safe to call frequently;
    /// skips the write if the counts haven't changed since the
    /// last call.
    static func writeIfChanged(accessories: [Accessory]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            // App Group not yet configured — ship-safe no-op.
            return
        }

        let snap = ActiveDevicesSnapshot(
            lightsOn: ActiveDevicesFilter.lightsOn(accessories).count,
            nowPlaying: ActiveDevicesFilter.nowPlaying(accessories).count,
            climateActive: ActiveDevicesFilter.climateActive(accessories).count,
            updatedAt: Date()
        )

        if let existingData = defaults.data(forKey: key),
           let existing = try? JSONDecoder().decode(ActiveDevicesSnapshot.self, from: existingData),
           existing.lightsOn == snap.lightsOn,
           existing.nowPlaying == snap.nowPlaying,
           existing.climateActive == snap.climateActive {
            // Counts identical — no reason to rewrite.
            return
        }

        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: key)
            // Widget refreshes on its own timeline, but nudge for
            // faster propagation when we know state changed.
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "com.houseconnect.activeDevices")
            #endif
        }
    }
}

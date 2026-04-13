//
//  MergedDeviceLookup.swift
//  house connect
//
//  Shared lookup from AccessoryID → MergedDevice so detail views can
//  use smart command routing (B6). Populated by AllDevicesView during
//  merge; consumed by detail views that need fallback routing.
//
//  Why an observable class instead of just passing MergedDevice through
//  navigation: DeviceDetailView is reached from multiple entry points
//  (All Devices, Home Dashboard room tiles, Notifications deep links).
//  Not all entry points have merge data. By putting the lookup in the
//  environment, detail views can optionally read it — if absent, they
//  fall back to single-provider routing (existing behavior).
//

import Foundation
import Observation

@MainActor
@Observable
final class MergedDeviceLookup {
    /// Maps any AccessoryID that participates in a merged device to
    /// that device's full MergedDevice metadata. Multiple AccessoryIDs
    /// may point to the same MergedDevice (one per provider).
    private(set) var byAccessoryID: [AccessoryID: MergedDevice] = [:]

    /// Called by AllDevicesView after each merge pass.
    func update(from mergedDevices: [MergedDevice]) {
        var new: [AccessoryID: MergedDevice] = [:]
        for merged in mergedDevices {
            // Only populate for devices that have >1 provider (actually merged).
            // Single-provider devices don't need smart routing.
            guard merged.providers.count > 1 else { continue }
            for id in merged.allAccessoryIDs {
                new[id] = merged
            }
        }
        byAccessoryID = new
    }

    /// Returns the MergedDevice for an accessory, or nil if it's not
    /// part of a multi-provider merge.
    func merged(for accessoryID: AccessoryID) -> MergedDevice? {
        byAccessoryID[accessoryID]
    }
}

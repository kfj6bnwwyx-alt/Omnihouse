//
//  MergedDevice.swift
//  house connect
//
//  Cross-provider device aggregate. Extracted from the legacy
//  AllDevicesView.swift on 2026-04-18 during the T3 migration cleanup
//  (Task 5 of the phase 1 plan). The struct and its pure merge helper
//  (`DeviceMerging`) are consumed by `MergedDeviceLookup`,
//  `ProviderRegistry`, the T3 device surfaces, and the unit test
//  target (`DeviceMergingTests`).
//

import Foundation

/// A single logical device unified across providers (HomeKit +
/// SmartThings + Sonos, etc.). Produced by `DeviceMerging.merge`.
///
/// Internal (not `private`) so the test target can construct these
/// directly via `@testable import house_connect`.
struct MergedDevice: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let name: String
    let category: Accessory.Category
    let roomName: String?
    let isReachable: Bool
    let providers: [ProviderID]
    let preferredID: AccessoryID
    /// Bonded parts from the representative accessory (home-theater
    /// satellite labels, stereo pair twin, etc.). Copied straight off
    /// the accessory the merge chose as the canonical one — currently
    /// only `SonosProvider` populates this field, but the plumbing is
    /// cross-ecosystem.
    let groupedParts: [String]?
    /// Casual zone-group membership on the representative accessory.
    /// Drives the "Playing with Kitchen, Office" overlay on the tile.
    let speakerGroup: SpeakerGroupMembership?

    // MARK: - Capability union (B6)

    /// Union of capabilities from ALL providers. For each kind, the
    /// value comes from the preferred (or first reachable) provider.
    let capabilities: [Capability]

    /// Maps each capability kind to the AccessoryIDs of providers that
    /// support it. Used by `SmartCommandRouter` to pick the best
    /// target for each command.
    let capabilityProviders: [Capability.Kind: [AccessoryID]]

    /// All AccessoryIDs in this merged bucket, for fallback routing.
    let allAccessoryIDs: [AccessoryID]

    // Hashable: exclude capabilityProviders (dictionaries with array
    // values don't auto-synthesize nicely). The `key` is already unique.
    static func == (lhs: MergedDevice, rhs: MergedDevice) -> Bool {
        lhs.key == rhs.key
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

// MARK: - DeviceMerging (pure, testable)

/// Pure functions that bucket a flat `[Accessory]` into `[MergedDevice]`.
///
/// Extracted from `AllDevicesView` so a unit test target can exercise
/// the match key + bucketing + representative-picking logic without
/// having to instantiate a whole `ProviderRegistry` and its provider
/// stack.
///
/// Design notes:
///
/// · `matchKey` is deliberately conservative — `"\(trimmed lowercased
///   name)|\(category rawValue)"`. It will NOT merge two devices named
///   differently on each side, and it WILL merge a bulb called
///   " Kitchen Lamp " on HomeKit with "kitchen lamp" on SmartThings.
///
/// · The representative accessory is picked by walking the caller's
///   `preferenceOrder` and taking the first provider that published
///   the device. If none match (shouldn't happen in prod — every
///   provider belongs in the order list), the first accessory in the
///   bucket wins so we never silently drop a device.
///
/// · `providers` on the merged entry is sorted into the canonical
///   `preferenceOrder` rather than dictionary iteration order, so the
///   chip row is stable across refreshes.
///
/// · `isReachable` is the OR of every instance — a single-path outage
///   (SmartThings cloud blip) shouldn't mark a bulb offline if
///   HomeKit can still see it on the LAN.
enum DeviceMerging {

    /// Soft-match key used to bucket accessories. Case- and
    /// whitespace-insensitive on the name; exact-match on category
    /// so a sensor and a light that happen to share a name stay
    /// separate.
    static func matchKey(for accessory: Accessory) -> String {
        let normalized = accessory.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(normalized)|\(accessory.category.rawValue)"
    }

    /// Merge a flat accessory list into deduped `MergedDevice` entries,
    /// sorted by display name (case-insensitive).
    ///
    /// - Parameters:
    ///   - accessories: The flat list from the registry.
    ///   - preferenceOrder: Provider preference order. The first
    ///     provider that published a given device becomes that device's
    ///     `preferredID`. Tests can pass an arbitrary order to verify
    ///     the tie-break behavior.
    ///   - roomNameResolver: A closure that maps a representative
    ///     accessory to its human-readable room name, or `nil` if the
    ///     accessory has no room (e.g. an unrouted Sonos speaker). The
    ///     view supplies a closure backed by the registry; tests can
    ///     pass `{ _ in nil }` or a hand-built lookup.
    static func merge(
        accessories: [Accessory],
        preferenceOrder: [ProviderID],
        roomNameResolver: (Accessory) -> String?
    ) -> [MergedDevice] {
        // Bucket pass — one key → [Accessory].
        var buckets: [String: [Accessory]] = [:]
        for accessory in accessories {
            let key = matchKey(for: accessory)
            buckets[key, default: []].append(accessory)
        }

        // Pick representative + build the merged entry for each bucket.
        let merged: [MergedDevice] = buckets.values.compactMap { group in
            guard !group.isEmpty else { return nil }

            let representative: Accessory = {
                for prov in preferenceOrder {
                    if let hit = group.first(where: { $0.id.provider == prov }) {
                        return hit
                    }
                }
                // Defensive fallback — we already guarded empty above,
                // so force-unwrap would also be safe, but keeping the
                // soft landing means a caller passing a preference
                // order that omits a real provider still gets a tile.
                return group[0]
            }()

            // Providers ordered by the caller's preference so the badge
            // row renders predictably. Providers that appear in the
            // bucket but NOT in `preferenceOrder` are appended at the
            // end in their observed order, as a belt-and-braces against
            // a caller passing a short list (unit tests do this).
            var providers: [ProviderID] = preferenceOrder.filter { prov in
                group.contains(where: { $0.id.provider == prov })
            }
            for accessory in group {
                if !providers.contains(accessory.id.provider) {
                    providers.append(accessory.id.provider)
                }
            }

            let anyReachable = group.contains(where: { $0.isReachable })

            // B6: Capability union — collect capabilities from ALL
            // providers, preferring values from reachable providers.
            var capsByKind: [Capability.Kind: Capability] = [:]
            var capProviders: [Capability.Kind: [AccessoryID]] = [:]
            // Process representative first so its values are the default.
            for acc in [representative] + group.filter({ $0.id != representative.id }) {
                for cap in acc.capabilities {
                    capProviders[cap.kind, default: []].append(acc.id)
                    // Prefer the first reachable provider's value
                    if capsByKind[cap.kind] == nil || (acc.isReachable && !group.first(where: { $0.id == representative.id })!.isReachable) {
                        capsByKind[cap.kind] = cap
                    }
                }
            }

            return MergedDevice(
                key: matchKey(for: representative),
                name: representative.name,
                category: representative.category,
                roomName: roomNameResolver(representative),
                isReachable: anyReachable,
                providers: providers,
                preferredID: representative.id,
                // Grouping metadata comes from the representative only.
                groupedParts: representative.groupedParts,
                speakerGroup: representative.speakerGroup,
                capabilities: Array(capsByKind.values),
                capabilityProviders: capProviders,
                allAccessoryIDs: group.map(\.id)
            )
        }

        return merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

//
//  DeviceLinkStore.swift
//  house connect
//
//  Persists user-created device links — pairs of AccessoryIDs that should
//  be treated as the same physical device even though their names differ
//  across providers (e.g. HomeKit "Office Lamp" ↔ HA "light.office_main").
//
//  Design:
//  · Each `ManualDeviceLink` pairs a `primaryID` (the canonical side,
//    usually HomeKit) with a `secondaryID` (the alias, usually HA).
//  · The store is serialised as JSON in UserDefaults under the key
//    "deviceLinks.v1". JSON roundtrip is cheap — the list is typically
//    under 100 entries.
//  · `DeviceMerging.merge()` reads `mergeKey(for:)` to override the
//    automatic name-based bucketing so linked pairs land in the same bucket.
//
//  Thread safety: `@MainActor @Observable` — all mutations happen on the
//  main actor and SwiftUI views observe changes automatically.
//

import Foundation
import Observation

// MARK: - Model

struct ManualDeviceLink: Codable, Identifiable, Hashable {
    let id: UUID
    /// The "canonical" side — typically HomeKit (shown first in the UI).
    let primaryID: AccessoryID
    /// The "alias" side — typically the HA entity or other provider.
    let secondaryID: AccessoryID
    var createdAt: Date

    init(primaryID: AccessoryID, secondaryID: AccessoryID) {
        self.id = UUID()
        self.primaryID = primaryID
        self.secondaryID = secondaryID
        self.createdAt = Date()
    }
}

// MARK: - Store

@MainActor
@Observable
final class DeviceLinkStore {
    private(set) var links: [ManualDeviceLink] = []

    private static let udKey = "deviceLinks.v1"

    init() {
        load()
    }

    // MARK: - Queries

    /// Returns all AccessoryIDs that participate in any manual link.
    func linkedIDs() -> Set<AccessoryID> {
        var result: Set<AccessoryID> = []
        for link in links {
            result.insert(link.primaryID)
            result.insert(link.secondaryID)
        }
        return result
    }

    /// True when the two IDs are manually linked (in either direction).
    func areLinked(_ a: AccessoryID, _ b: AccessoryID) -> Bool {
        links.contains { ($0.primaryID == a && $0.secondaryID == b)
                      || ($0.primaryID == b && $0.secondaryID == a) }
    }

    /// Returns a stable merge-key override for `id` when it participates
    /// in a manual link. Both the primary and secondary share the primary's
    /// natural `DeviceMerging.matchKey`. Returns `nil` when the accessory
    /// has no manual link.
    func overrideMatchKey(for accessory: Accessory) -> String? {
        if links.contains(where: { $0.primaryID == accessory.id }) {
            // This IS the primary — return its own key (no change needed for primary).
            return DeviceMerging.matchKey(for: accessory)
        }
        if let link = links.first(where: { $0.secondaryID == accessory.id }) {
            // This is the secondary — its override key is derived from the primary's
            // provider + nativeID string so the view can reconstruct it even when
            // the primary isn't loaded. We use a deterministic string rather than
            // the primary accessory's actual matchKey to avoid a registry lookup here.
            return "_manualLink|\(link.primaryID.provider.rawValue)|\(link.primaryID.nativeID)"
        }
        return nil
    }

    /// Returns the link for a given secondary AccessoryID, if any.
    func link(for secondaryID: AccessoryID) -> ManualDeviceLink? {
        links.first { $0.secondaryID == secondaryID }
    }

    // MARK: - Mutations

    /// Creates a new link between `primary` and `secondary`. No-ops if
    /// the pair already exists. Either ID being part of an existing link
    /// on the OTHER end is allowed — a device can be the primary of many
    /// links (e.g. one HomeKit device matched to both an HA and a
    /// SmartThings alias).
    @discardableResult
    func addLink(primary: AccessoryID, secondary: AccessoryID) -> ManualDeviceLink {
        // Idempotent: return the existing link if the pair already exists.
        if let existing = links.first(where: {
            ($0.primaryID == primary && $0.secondaryID == secondary)
                || ($0.primaryID == secondary && $0.secondaryID == primary)
        }) {
            return existing
        }
        let link = ManualDeviceLink(primaryID: primary, secondaryID: secondary)
        links.append(link)
        save()
        return link
    }

    /// Removes the link with the given UUID.
    func removeLink(id: UUID) {
        links.removeAll { $0.id == id }
        save()
    }

    /// Removes any link that contains `accessoryID` on either side.
    func removeLinks(involving accessoryID: AccessoryID) {
        links.removeAll { $0.primaryID == accessoryID || $0.secondaryID == accessoryID }
        save()
    }

    /// Nukes every stored link. Exposed so the Settings UI can offer
    /// a "Clear all" escape hatch — useful when stale test data piles
    /// up and the user can't tell which rows are current.
    func removeAllLinks() {
        links.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.udKey),
              let decoded = try? JSONDecoder().decode([ManualDeviceLink].self, from: data)
        else { return }
        // Dedupe defensively — treat (A,B) and (B,A) as the same pair.
        // Earlier builds may have written duplicates from double-tap
        // or re-runs of potential-match rows.
        var seen = Set<Set<AccessoryID>>()
        var uniq: [ManualDeviceLink] = []
        for link in decoded {
            let key: Set<AccessoryID> = [link.primaryID, link.secondaryID]
            if seen.insert(key).inserted {
                uniq.append(link)
            }
        }
        links = uniq
        if uniq.count != decoded.count { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(links) else { return }
        UserDefaults.standard.set(data, forKey: Self.udKey)
    }
}

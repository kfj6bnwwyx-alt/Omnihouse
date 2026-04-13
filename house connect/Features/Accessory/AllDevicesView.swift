//
//  AllDevicesView.swift
//  house connect
//
//  The "Devices" tab — a flat, searchable list of every accessory the
//  registry knows about, independent of room assignment.
//
//  Why this exists:
//  ----------------
//  The Home tab already groups by room (the "My Rooms" grid section is
//  primary real estate there), and Settings → Rooms & Zones is where
//  you manage which device belongs in which room. What was missing in
//  between was a screen that just answers "show me everything on my
//  network" — especially for Sonos players (which don't get a room
//  assignment at all in Phase 3a) and SmartThings / HomeKit / Nest
//  devices that a user hasn't sorted into rooms yet.
//
//  The prior second tab was `AllRoomsView`, which duplicated what Home
//  already showed. We moved AllRoomsView into Settings → Rooms & Zones
//  (same stack it was already registered in — it just stopped being a
//  top-level tab) and put this screen in its place.
//
//  Mental model — Devices vs Networks (added 2026-04-11):
//  ------------------------------------------------------
//  A single physical device may be controllable through more than one
//  ecosystem at once — e.g. a smart bulb paired through both HomeKit
//  and SmartThings, or a Sonos player that's also exposed via AirPlay
//  through HomeKit. We don't want the user to see the same thing as
//  two separate tiles, and we also don't want a modal "which one do
//  you want?" picker every time they tap.
//
//  So the tab has two modes:
//
//    · DEVICES (default) — the primary mental model. One tile per
//      physical thing, de-duped across providers by a soft match on
//      name + category. Each tile shows a small row of provider chips
//      (HK · ST · SONOS · NEST) so provenance is visible at a glance.
//      Tap routes to a PREFERRED provider's DeviceDetailView — the
//      first in the canonical order [HomeKit, SmartThings, Sonos, Nest].
//      HomeKit is first because it's local-network and therefore has
//      the lowest latency; SmartThings is cloud-dependent and slower.
//
//    · NETWORKS — the power-user flip. Sectioned by provider, so you
//      can eyeball exactly what each ecosystem is publishing. Useful
//      for debugging "why is this bulb showing up on both?" or "did
//      SmartThings finish re-syncing?". Shares the same DeviceTile
//      layout so the user's eye doesn't have to retrain.
//
//  Matching heuristic (intentionally simple):
//    key = "\(name.lowercased().trimmed)|\(category.rawValue)"
//  Conservative — won't merge two devices that were named differently
//  on each side, and collapses cleanly when only one provider has a
//  match. A smarter matcher (room-aware, fuzzy name) is in the Phase
//  3c capability-union story; this is enough to kill the obvious
//  duplicates today.
//

import SwiftUI

struct AllDevicesView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(MergedDeviceLookup.self) private var mergedLookup

    @State private var query: String = ""

    /// View mode toggle, persisted across launches. A user who lives
    /// in Networks mode (debugging an ecosystem, or who genuinely
    /// thinks in provider-buckets) shouldn't have to re-flip the
    /// segment every cold start. Default is `.devices` for new users
    /// because that's the primary mental model we're pushing.
    ///
    /// Stored as a raw String because `@AppStorage` doesn't round-trip
    /// arbitrary enums directly; we compute the typed value via a
    /// small getter/setter so the rest of the view sees a clean
    /// `DevicesViewMode`.
    @AppStorage("allDevicesView.mode") private var viewModeRaw: String = DevicesViewMode.devices.rawValue

    private var viewMode: DevicesViewMode {
        get { DevicesViewMode(rawValue: viewModeRaw) ?? .devices }
        nonmutating set { viewModeRaw = newValue.rawValue }
    }

    /// Binding wrapper so the segmented Picker can write straight into
    /// the persisted mode without the view having to hand-roll an
    /// onChange handler. Built on the fly in `body` so it picks up
    /// any future state changes.
    private var viewModeBinding: Binding<DevicesViewMode> {
        Binding(
            get: { viewMode },
            set: { viewModeRaw = $0.rawValue }
        )
    }

    /// User-configurable preference: when a device is published by
    /// more than one ecosystem, which one should the Devices tile
    /// route to on tap? Default is HomeKit because it's local-network
    /// (lowest latency, works without internet). A user who's all-in
    /// on SmartThings automations can flip this in Settings →
    /// Connections → Preferred Network; the tiles update in place.
    ///
    /// Persisted as a raw String for the same reason as
    /// `viewModeRaw` — AppStorage + enum raw values is the minimal
    /// viable path and avoids a JSON encoder for one-key state.
    @AppStorage("devices.preferredProvider") private var preferredProviderRaw: String = ProviderID.homeKit.rawValue

    /// The user's preferred routing provider, resolved live off
    /// AppStorage. Fall through to HomeKit on any garbage value so
    /// a corrupted setting can't break the tab.
    private var preferredProvider: ProviderID {
        ProviderID(rawValue: preferredProviderRaw) ?? .homeKit
    }

    /// Canonical fallback order used when the preferred provider
    /// doesn't publish a given device. We always put the preferred
    /// provider first, then walk the remaining providers in a
    /// stable order so the merged tile still has somewhere to land
    /// if (say) HomeKit doesn't happen to publish a Sonos-native
    /// player.
    ///
    /// The tail order is [HomeKit, SmartThings, Sonos, Nest] minus
    /// the preferred provider — deterministic, so two different
    /// dual-homed bulbs never route to different providers on the
    /// same screen.
    private var providerPreferenceOrder: [ProviderID] {
        let preferred = preferredProvider
        let tail: [ProviderID] = [.homeKit, .smartThings, .sonos, .nest]
            .filter { $0 != preferred }
        return [preferred] + tail
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                modeSwitcher
                searchField
                DisconnectedProviderBanners()
                content
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
        }
        // Pull-to-refresh fans out to every registered provider's
        // `refresh()` in parallel so a single downward tug re-polls
        // SmartThings, re-kicks Sonos Bonjour discovery, re-snapshots
        // HomeKit, and wakes up the demo Nest provider — all at once.
        // HomeKit and the demo Nest provider inherit a no-op default
        // impl, so this is effectively "poll everyone that has
        // polling to do", without the view having to know which
        // providers are polled vs. push-driven.
        //
        // Parallel fan-out via a TaskGroup: a slow SmartThings
        // response shouldn't block the faster Sonos re-discovery
        // finishing. The ScrollView's own refresh spinner hangs
        // until the whole group returns, which is exactly the
        // feedback we want — "refresh is done" should mean every
        // provider is done, not just the first one.
        .refreshable {
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in
                        await provider.refresh()
                    }
                }
            }
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("All Devices")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)
            Spacer()
            Text("\(headerCount)")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
                .monospacedDigit()
                .accessibilityLabel("\(headerCount) devices")
        }
        .accessibilityElement(children: .combine)
    }

    /// Count shown in the top-right of the header — the number of
    /// *logical things* in the current mode, not raw accessory count.
    /// In Devices mode that's merged devices (so a dual-homed bulb
    /// counts as one); in Networks mode it's the raw accessory count
    /// (so the same bulb counts twice — that IS the point of the
    /// Networks flip).
    private var headerCount: Int {
        switch viewMode {
        case .devices: return filteredMergedDevices.count
        case .rooms: return filteredMergedDevices.count
        case .networks: return filteredAccessories.count
        }
    }

    /// Segmented toggle for Devices vs Networks mental models.
    /// System segmented Picker keeps focus / accessibility / tint
    /// behavior correct without reinventing them — visual tint is
    /// pulled from Theme so it still reads as part of the Pencil
    /// design system. The label strings are deliberately short so
    /// the control doesn't crowd small screens.
    private var modeSwitcher: some View {
        // Three-way Pencil j8hFZ / rv14r switcher. "By Device" and
        // "By Room" are the primary user-facing axes; "Networks"
        // stays as a power-user debug mode for eyeballing what each
        // provider actually publishes. Kept under one segmented
        // Picker so keyboard / VoiceOver users cycle through all
        // three in a single focus target.
        Picker("View mode", selection: viewModeBinding) {
            Text("By Device").tag(DevicesViewMode.devices)
            Text("By Room").tag(DevicesViewMode.rooms)
            Text("Networks").tag(DevicesViewMode.networks)
        }
        .pickerStyle(.segmented)
        .tint(Theme.color.primary)
        .accessibilityHint("Switch between grouping devices by device, by room, or by network provider")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.color.muted)
            TextField("Search devices…", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.color.title)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.color.muted)
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Removes the current search filter")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Theme.color.cardFill)
                .shadow(color: Color.black.opacity(0.04),
                        radius: 6, x: 0, y: 2)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewMode {
        case .devices: devicesGrid
        case .rooms: roomsSections
        case .networks: networksSections
        }
    }

    // MARK: - Rooms mode (merged devices grouped by room name)

    /// Groups merged devices by their room name. Devices without a
    /// room (most Sonos players, pre-sorted HomeKit bulbs, etc.) get
    /// bucketed into an "Unassigned" section at the bottom so they're
    /// still discoverable — empty sections are elided entirely.
    @ViewBuilder
    private var roomsSections: some View {
        let groups = groupedByRoom
        if groups.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(group.title.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(Theme.color.subtitle)
                            Text("\(group.items.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.color.muted)
                                .monospacedDigit()
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(group.title), \(group.items.count) devices")
                        .accessibilityAddTraits(.isHeader)
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12),
                                      GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(group.items) { merged in
                                NavigationLink {
                                    DeviceDetailView(accessoryID: merged.preferredID)
                                        .environment(registry)
                                } label: {
                                    DeviceTile(
                                        name: merged.name,
                                        category: merged.category,
                                        roomName: merged.roomName,
                                        isReachable: merged.isReachable,
                                        providers: merged.providers,
                                        groupedParts: merged.groupedParts,
                                        speakerGroup: merged.speakerGroup
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    /// View-local DTO so the ForEach over grouped rooms can key off
    /// a stable String title without surfacing a nested dictionary.
    private struct RoomGroup {
        let title: String
        let items: [MergedDevice]
    }

    /// Walks the current filtered merged-devices list and buckets by
    /// room name. Keeps "Unassigned" last so users see real rooms
    /// first.
    private var groupedByRoom: [RoomGroup] {
        var buckets: [String: [MergedDevice]] = [:]
        for device in filteredMergedDevices {
            let key = device.roomName?.trimmingCharacters(in: .whitespaces) ?? ""
            let title = key.isEmpty ? "Unassigned" : key
            buckets[title, default: []].append(device)
        }
        let sortedTitles = buckets.keys.sorted { lhs, rhs in
            // Pin "Unassigned" to the bottom no matter the alphabet.
            if lhs == "Unassigned" { return false }
            if rhs == "Unassigned" { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return sortedTitles.map { title in
            RoomGroup(title: title, items: buckets[title] ?? [])
        }
    }

    // MARK: - Devices mode (merged by physical device)

    @ViewBuilder
    private var devicesGrid: some View {
        let items = filteredMergedDevices
        if items.isEmpty {
            emptyState
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12),
                          GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(items) { merged in
                    // View-based NavigationLink for the same reason as
                    // ProviderDevicesListView — we don't want to depend
                    // on a stack-level `.navigationDestination(for:
                    // AccessoryID.self)` that might be invisible to
                    // descendants pushed through intermediate views.
                    NavigationLink {
                        DeviceDetailView(accessoryID: merged.preferredID)
                            .environment(registry)
                    } label: {
                        DeviceTile(
                            name: merged.name,
                            category: merged.category,
                            roomName: merged.roomName,
                            isReachable: merged.isReachable,
                            providers: merged.providers,
                            groupedParts: merged.groupedParts,
                            speakerGroup: merged.speakerGroup
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Networks mode (flat, sectioned by provider)

    @ViewBuilder
    private var networksSections: some View {
        let sections = filteredNetworkSections
        if sections.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sections, id: \.provider) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(section.provider.displayLabel.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(Theme.color.subtitle)
                            Text("\(section.accessories.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.color.muted)
                                .monospacedDigit()
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(section.provider.displayLabel), \(section.accessories.count) devices")
                        .accessibilityAddTraits(.isHeader)
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12),
                                      GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(section.accessories) { accessory in
                                NavigationLink {
                                    DeviceDetailView(accessoryID: accessory.id)
                                        .environment(registry)
                                } label: {
                                    DeviceTile(
                                        name: accessory.name,
                                        category: accessory.category,
                                        roomName: roomName(for: accessory),
                                        isReachable: accessory.isReachable,
                                        providers: [accessory.id.provider],
                                        groupedParts: accessory.groupedParts,
                                        speakerGroup: accessory.speakerGroup
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(query.isEmpty ? "No devices yet" : "No matches")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
            Text(query.isEmpty
                 ? "Connect a provider in Settings → Connections to populate this list."
                 : "Try a different search term.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Data — flat

    /// Flat list across all providers, sorted by name. Offline devices
    /// aren't filtered out — the tile just reads "Offline" as its
    /// subtitle so the user can tap through to the troubleshooting view.
    private var filteredAccessories: [Accessory] {
        let all = registry.allAccessories.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }

    /// Accessories grouped by provider, in canonical preference order.
    /// Empty sections are dropped so the Networks view doesn't render
    /// "HomeKit · 0 devices" headers for ecosystems the user hasn't
    /// connected yet.
    private var filteredNetworkSections: [NetworkSection] {
        let byProvider = Dictionary(grouping: filteredAccessories, by: { $0.id.provider })
        return providerPreferenceOrder.compactMap { provider -> NetworkSection? in
            guard let list = byProvider[provider], !list.isEmpty else { return nil }
            return NetworkSection(provider: provider, accessories: list)
        }
    }

    // MARK: - Data — merged (device-first mental model)

    /// Collapses the flat accessory list into one entry per physical
    /// device, using a soft match on `(lowercased trimmed name, category)`.
    /// The match key is intentionally conservative — it won't accidentally
    /// merge two differently-named devices, and it's case/whitespace
    /// tolerant so minor spelling differences between HomeKit's and
    /// SmartThings' labels still collapse correctly.
    ///
    /// Each merged entry picks a PREFERRED `AccessoryID` for tap-through
    /// routing: the first provider in `providerPreferenceOrder` that
    /// actually published the device. That way tapping a dual-homed bulb
    /// lands on the HomeKit detail screen (fast, local) rather than the
    /// SmartThings one (cloud, laggy), without ever asking the user to
    /// resolve the ambiguity.
    private var filteredMergedDevices: [MergedDevice] {
        // Pure, testable merge lives in DeviceMerging (file scope, below).
        // The view only contributes (a) the accessory list from the
        // registry, (b) the current preference order, and (c) a closure
        // that resolves room names for the representative accessory.
        let merged = DeviceMerging.merge(
            accessories: registry.allAccessories,
            preferenceOrder: providerPreferenceOrder,
            roomNameResolver: { [weak registry] accessory in
                guard let registry else { return nil }
                guard let roomID = accessory.roomID,
                      let provider = registry.provider(for: accessory.id.provider),
                      let room = provider.rooms.first(where: { $0.id == roomID })
                else { return nil }
                return room.name
            }
        )
        // B6: Update the shared lookup so detail views can use smart
        // routing for dual-homed devices. Side effect in a computed
        // property is normally avoided, but this is the natural
        // observation-driven merge point and the lookup is @Observable.
        DispatchQueue.main.async { [merged] in
            mergedLookup.update(from: merged)
        }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return merged }
        return merged.filter {
            $0.name.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }

    /// Best-effort room label for the subtitle line. Sonos speakers
    /// typically have no roomID in Phase 3a, so we fall back to nil
    /// (DeviceTile.subtitle then falls back to "Offline" or the
    /// category label, so the tile is never blank).
    private func roomName(for accessory: Accessory) -> String? {
        if let roomID = accessory.roomID,
           let provider = registry.provider(for: accessory.id.provider),
           let room = provider.rooms.first(where: { $0.id == roomID }) {
            return room.name
        }
        return nil
    }
}

// MARK: - Supporting types

/// Which mental model the Devices tab is currently showing.
/// `.devices` is the default ("one tile per physical thing, chips
/// show which networks control it"); `.networks` is the power-user
/// flip ("flat list grouped by ecosystem").
///
/// Stored as a String raw-value so `@AppStorage` can round-trip it
/// across launches — the user's last mode choice survives app
/// restarts, so a power user who lives in Networks mode doesn't
/// have to re-toggle on every cold start.
enum DevicesViewMode: String, Hashable {
    case devices
    case rooms
    case networks
}

/// A single physical device, possibly controllable through multiple
/// providers. `preferredID` is the routing target for tap-through;
/// `providers` drives the chip row on the tile.
///
/// Internal (not `private`) so the test target can construct these
/// directly via `@testable import house_connect` — the tile view and
/// the merge algorithm are the only production consumers.
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

/// One provider section for Networks mode.
private struct NetworkSection {
    let provider: ProviderID
    let accessories: [Accessory]
}

// MARK: - DeviceMerging (pure, testable)

/// Pure functions that bucket a flat `[Accessory]` into `[MergedDevice]`.
///
/// Extracted from `AllDevicesView` so a unit test target can exercise
/// the match key + bucketing + representative-picking logic without
/// having to instantiate a whole `ProviderRegistry` and its provider
/// stack. The view's `filteredMergedDevices` composes these with the
/// registry it has in hand.
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

// MARK: - Tile

/// Square-ish card mirroring `RoomTile` over on the Home tab. Same
/// lavender chip + title + subtitle shape so the user's eye doesn't
/// have to retrain across tabs. Takes a raw bag of fields rather
/// than an `Accessory` so the merged-device row can reuse it without
/// inventing a fake synthetic Accessory.
private struct DeviceTile: View {
    let name: String
    let category: Accessory.Category
    let roomName: String?
    let isReachable: Bool
    /// One or more providers that publish this device. A single-entry
    /// array renders a single pill (today's look); a multi-entry
    /// array renders a row of compact capsules so dual-homed devices
    /// are obvious at a glance.
    let providers: [ProviderID]
    /// Bonded structural parts for a home-theater / stereo-pair setup.
    /// Non-nil → the tile shows a "N speakers" chip in the header and
    /// the subtitle reads "Arc · Sub · 2 rears" (or similar compact
    /// summary) so the user knows at a glance this is a bonded set.
    let groupedParts: [String]?
    /// Casual zone-group membership. Non-nil → the tile shows a
    /// "Playing with <other rooms>" subtitle overlay. Independent
    /// from `groupedParts`; a bonded home theater can ALSO be
    /// grouped into a casual multi-room party.
    let speakerGroup: SpeakerGroupMembership?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                IconChip(systemName: iconName, size: 40)
                // Bonded-set / casual-group indicator glyph directly
                // beside the device icon. Rendered ONLY when one of
                // the two grouping states is active, so ordinary tiles
                // stay visually unchanged. Placed in the top-left next
                // to the icon (not folded into the provider badge row)
                // because grouping is a *property of the device*, not
                // provenance — pairing it with the icon reads right.
                if let groupingGlyph {
                    Image(systemName: groupingGlyph)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.color.primary)
                        .padding(6)
                        .background(
                            Circle().fill(Theme.color.iconChipFill)
                        )
                        .offset(x: -6, y: -6)
                        .accessibilityLabel(groupingAccessibilityLabel ?? "")
                }
                Spacer()
                providerBadgeRow
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
                // Optional second subtitle line for grouping context.
                // Rendered below the primary subtitle so the top line
                // remains the room/offline/category tag the user's eye
                // is already trained on. Hidden entirely when there's
                // no grouping state, so ordinary tiles are unchanged.
                if let groupingSubtitle {
                    // Slightly bolder than the category line and tinted
                    // in the accent color so the user's eye catches it
                    // as "status/grouping info" rather than "more of the
                    // same gray subtitle".
                    Text(groupingSubtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.color.primary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
        .opacity(isReachable ? 1.0 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tileAccessibilityLabel)
        .accessibilityValue(tileAccessibilityValue)
        .accessibilityHint("Double tap to view device details")
        .accessibilityAddTraits(.isButton)
    }

    /// SF Symbol for the corner grouping-state glyph, or nil when
    /// the tile has no grouping to advertise. Bonded sets take
    /// priority — a bar + sub is ALWAYS a bonded set even when it's
    /// also in a casual zone group, and that's the more interesting
    /// fact to surface at a glance ("this tile represents multiple
    /// physical speakers" beats "this tile is currently playing with
    /// some other room"). Falls through to the radiowaves glyph for
    /// casual-group-only tiles.
    private var groupingGlyph: String? {
        if let groupedParts, !groupedParts.isEmpty {
            return "hifispeaker.2.fill"
        }
        if let speakerGroup, !speakerGroup.otherMemberNames.isEmpty {
            return "dot.radiowaves.left.and.right"
        }
        return nil
    }

    /// VoiceOver label for the grouping glyph. Spoken in addition to
    /// the tile's name/subtitle so assistive tech users get the same
    /// "this is bonded / this is playing with others" context sighted
    /// users get from the corner badge.
    private var groupingAccessibilityLabel: String? {
        if let groupedParts, !groupedParts.isEmpty {
            return "Bonded set of \(groupedParts.count) speakers"
        }
        if let speakerGroup, !speakerGroup.otherMemberNames.isEmpty {
            return "Playing together with \(speakerGroup.otherMemberNames.joined(separator: ", "))"
        }
        return nil
    }

    /// Secondary line announcing bonded-set membership or casual zone
    /// grouping, in that priority order. Bonded sets are structural
    /// (they describe the device itself), so they lead; casual
    /// groups are stateful and more like an overlay.
    ///
    /// Examples:
    ///   · Home theater only:  "4 speakers · Sub · 2 rears"
    ///   · Playing together:   "Playing with Kitchen, Office"
    ///   · Both:               "4 speakers · +2 grouped"
    ///   · Neither:            nil (no extra line rendered)
    private var groupingSubtitle: String? {
        var fragments: [String] = []

        if let groupedParts, !groupedParts.isEmpty {
            fragments.append("\(groupedParts.count) speakers")
        }

        if let speakerGroup, !speakerGroup.otherMemberNames.isEmpty {
            if groupedParts?.isEmpty == false {
                // Bonded + casual → compact it down to a count so
                // the second line doesn't overflow.
                fragments.append("+\(speakerGroup.otherMemberNames.count) grouped")
            } else {
                // Casual only → spell out the room names for context.
                fragments.append("Playing with \(speakerGroup.otherMemberNames.joined(separator: ", "))")
            }
        }

        return fragments.isEmpty ? nil : fragments.joined(separator: " · ")
    }

    /// Row of uppercase provenance chips in the top-right. On single-
    /// provider tiles this looks identical to today's layout; on
    /// dual-homed devices it reads e.g. `HK · ST`. Capped at 3 chips
    /// visually — more than that doesn't fit in the corner and also
    /// never happens in practice.
    private var providerBadgeRow: some View {
        HStack(spacing: 4) {
            ForEach(providers.prefix(3), id: \.self) { provider in
                Text(shortLabel(for: provider))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.color.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Theme.color.iconChipFill)
                    )
                    .accessibilityLabel(provider.displayLabel)
            }
        }
    }

    private func shortLabel(for provider: ProviderID) -> String {
        switch provider {
        case .homeKit: "HK"
        case .smartThings: "ST"
        case .sonos: "SONOS"
        case .nest: "NEST"
        }
    }

    /// Category-to-glyph mapping, matching `ProviderDevicesListView`
    /// and `RoomDetailView` so a single device looks the same
    /// everywhere it appears.
    private var iconName: String {
        switch category {
        case .light: "lightbulb.fill"
        case .switch: "switch.2"
        case .outlet: "poweroutlet.type.b.fill"
        case .thermostat: "thermometer.medium"
        case .lock: "lock.fill"
        case .sensor: "sensor.fill"
        case .camera: "video.fill"
        case .fan: "fan.fill"
        case .blinds: "blinds.horizontal.closed"
        case .speaker: "hifispeaker.fill"
        case .television: "tv.fill"
        case .smokeAlarm: "smoke.fill"
        case .other: "questionmark.app.fill"
        }
    }

    /// Secondary line: prefer the room name, else call out "Offline",
    /// else fall back to the category label so a tile is never blank.
    /// When the device is unreachable AND has a room, show both so the
    /// user knows where the device lives and that it's disconnected.
    private var subtitle: String {
        if !isReachable {
            if let roomName, !roomName.isEmpty {
                return "\(roomName) · Disconnected"
            }
            return "Disconnected"
        }
        if let roomName, !roomName.isEmpty { return roomName }
        return category.rawValue.capitalized
    }

    // MARK: - Accessibility

    /// Combined label: "[Device name], [Room], [Status]".
    /// Reads naturally as a single VoiceOver utterance.
    private var tileAccessibilityLabel: String {
        var parts: [String] = [name]
        if let roomName, !roomName.isEmpty {
            parts.append(roomName)
        }
        if !isReachable {
            parts.append("Disconnected")
        } else {
            parts.append(category.rawValue.capitalized)
        }
        return parts.joined(separator: ", ")
    }

    /// Value string surfacing provider provenance and grouping state
    /// so assistive tech users get the same information as sighted
    /// users reading the badge row and grouping subtitle.
    private var tileAccessibilityValue: String {
        var fragments: [String] = []
        let providerNames = providers.map { shortLabel(for: $0) }
        if !providerNames.isEmpty {
            fragments.append("Available on \(providerNames.joined(separator: ", "))")
        }
        if let groupingAccessibilityLabel {
            fragments.append(groupingAccessibilityLabel)
        }
        if let groupingSubtitle {
            fragments.append(groupingSubtitle)
        }
        return fragments.joined(separator: ". ")
    }
}

//
//  SonosProvider.swift
//  house connect
//
//  Concrete `AccessoryProvider` for Sonos over the local network. Each
//  discovered player becomes one `Accessory` in the `.speaker` category,
//  exposing playback / volume / mute capabilities.
//
//  Phase 3a scope:
//    - Discover players via Bonjour (SonosDiscovery)
//    - One synthetic "home" so the Rooms list has somewhere to put them
//    - No room CRUD (Sonos groups are a different concept — deferred)
//    - Play / Pause / Next / Previous / SetVolume / SetMute commands
//    - Status refresh reads transport state + volume + mute per player
//
//  What's deliberately NOT here:
//    - Now-playing track metadata (requires parsing DIDL-Lite; later)
//    - Group / zone management (Sonos' own concept; add in Phase 3b)
//    - Airplay-only speakers (Sonos AirPlay group vs. real Sonos groups)
//
//  Local network permission:
//    The first time NWBrowser is started on iOS 14+ the system shows the
//    Local Network privacy prompt. If the user denies it, the Bonjour
//    browser goes straight to `.failed` and we surface `.denied`.
//

import Foundation
import Observation

@MainActor
@Observable
final class SonosProvider: AccessoryProvider {
    let id: ProviderID = .sonos
    let displayName: String = "Sonos"

    /// Sonos has no "home" concept, but the Rooms-list UI groups by home,
    /// so we ship a synthetic single-home entry. Real Sonos zones may
    /// appear as rooms in the future once we handle grouping.
    private(set) var homes: [Home] = [
        Home(id: SonosProvider.syntheticHomeID,
             name: "Sonos (local)",
             isPrimary: false,
             provider: .sonos)
    ]
    private(set) var rooms: [Room] = []
    private(set) var accessories: [Accessory] = []
    private(set) var authorizationState: ProviderAuthorizationState = .notDetermined

    /// Last error surfaced during a refresh, so the UI can show it.
    private(set) var lastError: String?

    /// Refresh in flight flag (for spinner UI).
    private(set) var isRefreshing: Bool = false

    /// Timestamp of the most recent successful refresh, so the Connections
    /// screen can show "Last refreshed 2 min ago".
    private(set) var lastRefreshed: Date?

    @ObservationIgnored private let discovery = SonosDiscovery()
    @ObservationIgnored private let soap = SonosSOAPClient()
    @ObservationIgnored private var didStart = false

    /// Most recent household topology snapshot. `nil` until the first
    /// successful `GetZoneGroupState` response comes back — in that
    /// window `rebuildAccessories(from:)` renders the flat legacy view
    /// (one tile per Bonjour player, no grouping). After a topology
    /// fetch succeeds we re-run rebuild so bonded satellites disappear
    /// and casual groups surface their membership chips.
    @ObservationIgnored private var currentTopology: SonosTopology?

    /// Used as the `homeID` for the synthetic Sonos home.
    nonisolated static let syntheticHomeID = "sonos.local"

    init() {}

    // MARK: - AccessoryProvider

    func start() async {
        guard !didStart else { return }
        didStart = true

        discovery.onChange = { [weak self] players in
            guard let self else { return }
            // First pass — rebuild against whatever topology we already
            // have (possibly nil on the very first discovery callback).
            // Without this pass the UI would sit blank until the
            // topology fetch returned ~1s later, which feels broken.
            self.rebuildAccessories(from: players, topology: self.currentTopology)

            // A non-empty discovery set means Local Network definitely
            // works — clear any prior failure state.
            if !players.isEmpty {
                self.authorizationState = .authorized
                self.lastError = nil
            }

            // Background chain: fetch topology → re-rebuild (so bonded
            // satellites disappear and casual groups surface) → refresh
            // per-player transport state. Done serially because each
            // step depends on the previous.
            Task {
                await self.refreshTopology()
                self.rebuildAccessories(
                    from: self.discovery.players,
                    topology: self.currentTopology
                )
                await self.refreshAllStatuses()
            }
        }

        discovery.onFailure = { [weak self] message in
            // Bonjour browser failed outright. Almost always means the
            // user denied Local Network permission, or Info.plist is
            // missing `NSBonjourServices = [_sonos._tcp]`. Flip state
            // so the badge reads "Denied" and the footer hint matters.
            guard let self else { return }
            self.authorizationState = .denied
            self.lastError = message
            self.accessories = []
        }

        discovery.start()

        // We're optimistic: assume the prompt will be approved. If the
        // browser fails (denied) the handler flips us to `.denied`.
        authorizationState = .authorized
    }

    func execute(_ command: AccessoryCommand, on accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .sonos,
                     "Routing bug: non-Sonos ID sent to SonosProvider")
        guard let player = discovery.players.first(where: { $0.nativeID == accessoryID.nativeID }) else {
            throw ProviderError.accessoryNotFound
        }
        // When the player is a follower in a multi-room zone group,
        // transport commands (play/pause/next/previous/setPlayMode) must
        // be addressed to the GROUP COORDINATOR — a follower will refuse
        // them with `UPnPError 701 "Transition not available"`. Volume
        // and mute remain per-speaker because Sonos models those at the
        // RenderingControl level per player (not per group).
        //
        // For standalone players (or players that already ARE the
        // coordinator) `transportTarget` returns the player's own
        // host:port, so this is always safe to call.
        let transport = transportTarget(for: player)
        do {
            switch command {
            case .play:
                try await soap.play(host: transport.host, port: transport.port)
            case .pause:
                try await soap.pause(host: transport.host, port: transport.port)
            case .stop:
                try await soap.stop(host: transport.host, port: transport.port)
            case .next:
                try await soap.next(host: transport.host, port: transport.port)
            case .previous:
                try await soap.previous(host: transport.host, port: transport.port)
            case .setVolume(let percent):
                // Per-speaker: the user tapped Volume on THIS tile.
                try await soap.setVolume(host: player.host, port: player.port, percent: percent)
            case .setGroupVolume(let percent):
                // Group master: route to the coordinator via
                // `transportTarget` so a follower-viewed slider still
                // actuates the real group value. Sonos scales every
                // member's individual RenderingControl value
                // proportionally, preserving the relative mix.
                try await soap.setGroupVolume(
                    host: transport.host,
                    port: transport.port,
                    percent: percent
                )
            case .setMute(let muted):
                // Per-speaker: same reason.
                try await soap.setMute(host: player.host, port: player.port, muted: muted)
            case .setShuffle(let on):
                // Sonos combines shuffle + repeat into one PlayMode string, so
                // we have to preserve the current repeat mode when toggling
                // shuffle. Read it off the local accessory snapshot rather
                // than hitting the speaker again — the snapshot is what the
                // UI just rendered against, so it's the right source of truth
                // for "what the user intended to preserve".
                let currentRepeat = accessories.first(where: { $0.id == accessoryID })?.repeatMode ?? .off
                let mode = SonosPlayMode.string(shuffle: on, repeatMode: currentRepeat)
                // Play mode is a transport attribute — route to coordinator.
                try await soap.setPlayMode(host: transport.host, port: transport.port, mode: mode)
            case .setRepeatMode(let repeatMode):
                let currentShuffle = accessories.first(where: { $0.id == accessoryID })?.isShuffling ?? false
                let mode = SonosPlayMode.string(shuffle: currentShuffle, repeatMode: repeatMode)
                try await soap.setPlayMode(host: transport.host, port: transport.port, mode: mode)
            case .joinSpeakerGroup(let targetID):
                // Routing sanity: target must be a Sonos accessory too.
                // Cross-provider "join" makes no sense — AirPlay bridging
                // is a future problem.
                guard targetID.provider == .sonos else {
                    throw ProviderError.unsupportedCommand
                }
                // Don't let the UI try to "join" yourself — Sonos would
                // accept it and produce a weird no-op state transition.
                guard targetID != accessoryID else { return }
                // Resolve the target's CURRENT group coordinator. The
                // user tapped "Group with Kitchen", but if Kitchen is
                // already in a group led by Office, what we actually
                // want is "point this speaker at Office", not at
                // Kitchen. `coordinatorUUID(forHost:)` walks the cached
                // topology and returns the right UUID for us.
                guard let coordUUID = coordinatorUUID(forHost: targetID.nativeID) else {
                    // No topology yet, or target isn't in any group we
                    // know about (e.g. it dropped off the network
                    // between render and tap). Surface as an error
                    // rather than silently doing nothing — the user
                    // pressed a button and deserves feedback.
                    throw ProviderError.underlying(
                        "Can't find a zone group for the target speaker — refresh and try again."
                    )
                }
                try await soap.joinGroup(
                    host: player.host,
                    port: player.port,
                    coordinatorUUID: coordUUID
                )

            case .leaveSpeakerGroup:
                try await soap.leaveGroup(host: player.host, port: player.port)

            case .setPower,
                 .setBrightness,
                 .setHue,
                 .setSaturation,
                 .setColorTemperature,
                 .setTargetTemperature,
                 .setHVACMode,
                 .selfTest:
                throw ProviderError.unsupportedCommand
            }
        } catch let error as SonosSOAPError {
            throw ProviderError.underlying(error.localizedDescription)
        }
        // Optimistic refresh so the UI reflects the new state without a
        // full pass. Don't await — let the user's next tap land immediately.
        //
        // Grouping writes (`joinSpeakerGroup` / `leaveSpeakerGroup`) need
        // the full topology chain instead of a bare per-player status
        // refresh, because the whole POINT of a grouping command is to
        // mutate household-level zone-group state that only
        // `GetZoneGroupState` can surface. Without the topology fetch
        // the new membership wouldn't actually show up in the UI until
        // the next manual refresh — defeating the optimism.
        switch command {
        case .joinSpeakerGroup, .leaveSpeakerGroup:
            Task {
                // Sonos needs a moment to propagate the new group state
                // internally before GetZoneGroupState reflects it.
                // ~300ms is enough in practice; any shorter and the
                // refetch sometimes still returns the pre-command view.
                try? await Task.sleep(nanoseconds: 300_000_000)
                await self.refreshTopology()
                self.rebuildAccessories(
                    from: self.discovery.players,
                    topology: self.currentTopology
                )
                await self.refreshAllStatuses()
            }
        default:
            Task { await self.refreshStatus(for: player) }
        }
    }

    /// Looks up the current group coordinator UUID for the player at
    /// the given host. Used by `joinSpeakerGroup` to turn the
    /// user-facing "Group with Kitchen" request into the Sonos-level
    /// "SetAVTransportURI x-rincon:<coord>" write — we need the
    /// coordinator of whatever group Kitchen is currently IN, not
    /// Kitchen's own UUID (those only match if Kitchen is already the
    /// coordinator of its group, which is not always true).
    ///
    /// Returns nil if we have no topology yet OR the host isn't
    /// represented in any zone group we know about.
    private func coordinatorUUID(forHost host: String) -> String? {
        guard let topo = currentTopology else { return nil }
        for group in topo.zoneGroups {
            let memberHosts = Set(group.members.compactMap { $0.locationHost })
            if memberHosts.contains(host) {
                return group.coordinatorUUID
            }
        }
        return nil
    }

    /// Returns the (host, port) that transport commands (play, pause,
    /// next, previous, setPlayMode) should be sent to for this player.
    ///
    /// On Sonos, only the coordinator of a zone group can accept an
    /// AVTransport state change — a follower will return
    /// `UPnPError 701 "Transition not available"`. When the player is
    /// standalone or IS the coordinator, we return its own host:port.
    /// When it's a follower in a multi-member group, we walk the
    /// cached topology to find the coordinator's host and reroute
    /// there.
    ///
    /// Falls through to the player's own host:port on any lookup
    /// miss — no topology, player not found in topology, coordinator
    /// host missing — because the worst case is the same UPnP 701 we
    /// were already going to get, and the best case is that the
    /// player happens to be standalone and it just works.
    private func transportTarget(for player: SonosDiscoveredPlayer) -> (host: String, port: Int) {
        guard let topo = currentTopology else {
            return (player.host, player.port)
        }
        for group in topo.zoneGroups {
            guard group.members.contains(where: { $0.locationHost == player.host }) else {
                continue
            }
            // Solo group — just us. No reroute needed.
            guard group.members.count > 1 else {
                return (player.host, player.port)
            }
            // Find the coordinator member's host.
            guard let coord = group.members.first(where: { $0.uuid == group.coordinatorUUID }),
                  let coordHost = coord.locationHost else {
                return (player.host, player.port)
            }
            // Already the coordinator — no reroute.
            if coordHost == player.host {
                return (player.host, player.port)
            }
            // Reroute. Prefer the Bonjour-discovered port over a hardcoded
            // 1400 so a firmware port change (unlikely but possible) doesn't
            // silently break grouped transport.
            if let coordPlayer = discovery.players.first(where: { $0.host == coordHost }) {
                print("[sonos.route] rerouting transport from \(player.host) → coordinator \(coordHost):\(coordPlayer.port)")
                return (coordPlayer.host, coordPlayer.port)
            }
            print("[sonos.route] coordinator \(coordHost) not in Bonjour set — using 1400")
            return (coordHost, 1400)
        }
        return (player.host, player.port)
    }

    // MARK: - Rename
    //
    // Sonos exposes a control action (`SetRoomName`) but it's on a device-
    // specific service we don't speak yet. Leaving default-throw for now
    // so the UI surfaces "unsupported" — easier to add when we actually
    // want the feature.

    // MARK: - Refresh

    /// Called by the "Refresh now" button in Settings. Does two things:
    ///   1. Tears down and restarts the Bonjour browser so we re-kick
    ///      discovery (covers the case where the user just granted
    ///      Local Network permission, or a speaker just came online).
    ///   2. After a short grace window, re-polls transport/volume/mute
    ///      state for every player we currently know about.
    /// Without the restart, a zero-speaker state would leave Refresh
    /// feeling like a dead button — it would iterate nothing.
    /// Removes a Sonos speaker from the local accessory list. Sonos
    /// devices are discovered via Bonjour — they aren't "paired" in the
    /// same way a HomeKit accessory is — so removal just hides the speaker
    /// from our view until the next Bonjour sweep re-discovers it. If the
    /// user truly wants to forget the speaker, they'd factory-reset it in
    /// the Sonos app. For our purposes this is enough: the tile disappears
    /// and the device count updates immediately.
    func removeAccessory(_ accessoryID: AccessoryID) async throws {
        precondition(accessoryID.provider == .sonos)
        accessories.removeAll { $0.id == accessoryID }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Clear any prior failure so the UI doesn't show a stale error
        // while we're re-trying.
        lastError = nil

        // Restart Bonjour discovery. Results trickle in via onChange on
        // the underlying browser queue, not synchronously.
        discovery.restart()

        // Give the browser a moment to surface results before we start
        // polling statuses. 1.5s is enough for same-subnet Bonjour on a
        // typical home network; any longer and the button feels stuck.
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Re-fetch topology so bonded sets and casual groups pick up
        // changes the user made in the Sonos app between refreshes
        // (e.g. they just grouped Kitchen into the Family Room zone).
        // Then re-rebuild so the new grouping takes effect BEFORE the
        // per-player status sweep writes capability values into the
        // refreshed accessory list.
        await refreshTopology()
        rebuildAccessories(from: discovery.players, topology: currentTopology)

        await refreshAllStatuses()
        lastRefreshed = Date()
    }

    private func refreshAllStatuses() async {
        for player in discovery.players {
            await refreshStatus(for: player)
        }
    }

    /// Targeted status refresh for a single accessory. Used by the
    /// Sonos detail view to keep its transport snapshot fresh while
    /// the user is looking at it — without paying for a whole-household
    /// sweep on every poll tick. Safe to call in a tight polling loop
    /// because the underlying SOAP reads are bounded by a 4s timeout
    /// and the total cost is ~100–200ms per cycle on a healthy LAN.
    ///
    /// Silently no-ops when the accessoryID isn't a Sonos one or the
    /// discovery set doesn't hold a matching player — matches the
    /// shape of `execute(_:on:)` so callers don't have to guard.
    func refreshAccessory(_ accessoryID: AccessoryID) async {
        guard accessoryID.provider == .sonos else { return }
        guard let player = discovery.players.first(where: { $0.nativeID == accessoryID.nativeID }) else {
            return
        }
        await refreshStatus(for: player)
    }

    /// Fetches the household-wide zone group topology from any one
    /// reachable player and caches it in `currentTopology`. Any player
    /// on the same household returns the full view — bonded satellites
    /// gossip the same state internally — so we don't need to pick a
    /// specific one.
    ///
    /// Errors are surfaced into `lastError` with a `[topology]` prefix
    /// so they show up distinctly in Settings → Connections, and we
    /// also print diagnostic details to the Xcode console. Earlier
    /// versions silently swallowed the error under the theory that
    /// grouping is a progressive enhancement — which turned out to
    /// hide a real bug where bonded home theater sets weren't
    /// collapsing into a single tile. Surfacing the failure is the
    /// only way to distinguish "old firmware, no topology service"
    /// from "our parser broke on this firmware's XML shape".
    private func refreshTopology() async {
        guard let first = discovery.players.first else {
            currentTopology = nil
            print("[sonos.topology] skip: no discovered players yet")
            return
        }
        print("[sonos.topology] fetching from \(first.displayName) @ \(first.host):\(first.port)")
        do {
            let topo = try await soap.getZoneGroupState(
                host: first.host,
                port: first.port
            )
            currentTopology = topo
            print("[sonos.topology] parsed \(topo.zoneGroups.count) zone group(s):")
            for (gi, group) in topo.zoneGroups.enumerated() {
                print("  group[\(gi)] id=\(group.groupID) coord=\(group.coordinatorUUID) members=\(group.members.count)")
                for (mi, member) in group.members.enumerated() {
                    let sats = member.satellites
                        .map { "\($0.displayLabel)@\($0.locationHost ?? "?")" }
                        .joined(separator: ",")
                    print("    member[\(mi)] name=\"\(member.zoneName)\" host=\(member.locationHost ?? "?") uuid=\(member.uuid) satellites=[\(sats)]")
                }
            }
            // Side-by-side host comparison: the #1 reason rebuild fails
            // to hide bonded satellites is that the Location URL host
            // doesn't match the Bonjour-reported host string for the
            // same player. Print both sets so the mismatch (if any)
            // is obvious at a glance.
            let bonjourHosts = Set(discovery.players.map(\.host))
            var topoHosts: Set<String> = []
            for group in topo.zoneGroups {
                for member in group.members {
                    if let h = member.locationHost { topoHosts.insert(h) }
                    for sat in member.satellites {
                        if let h = sat.locationHost { topoHosts.insert(h) }
                    }
                }
            }
            print("[sonos.topology] bonjour hosts: \(bonjourHosts.sorted())")
            print("[sonos.topology] topology hosts: \(topoHosts.sorted())")
            let onlyInBonjour = bonjourHosts.subtracting(topoHosts)
            let onlyInTopo = topoHosts.subtracting(bonjourHosts)
            if !onlyInBonjour.isEmpty {
                print("[sonos.topology] ⚠️ hosts in Bonjour but NOT in topology: \(onlyInBonjour.sorted())")
            }
            if !onlyInTopo.isEmpty {
                print("[sonos.topology] ⚠️ hosts in topology but NOT in Bonjour: \(onlyInTopo.sorted())")
            }
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            print("[sonos.topology] ❌ fetch failed: \(msg)")
            // Surface so Settings → Connections shows it distinctly.
            // Use the `[topology]` prefix so it's easy to grep for
            // and obviously different from core-read errors.
            if lastError == nil {
                lastError = "[topology] \(first.displayName): \(msg)"
            }
        }
    }

    private func refreshStatus(for player: SonosDiscoveredPlayer) async {
        // We treat the five SOAP reads as two tiers:
        //   * CORE reads (state / volume / mute) decide reachability. If any
        //     of them succeed, the speaker is reachable — we don't want the
        //     UI to flip to offline just because a mute lookup happened to
        //     time out.
        //   * SECONDARY reads (playMode / positionInfo) are cosmetic — they
        //     feed shuffle/repeat/nowPlaying, which the UI is already
        //     willing to render as "unavailable" when nil. A failure on
        //     these MUST NOT affect reachability or stomp an existing
        //     now-playing snapshot while a valid core refresh is in flight.
        //
        // We also fall back to `existing.isReachable` when ALL core reads
        // fail — a single flaky refresh cycle shouldn't mark an otherwise
        // healthy speaker offline.
        var firstError: Error?

        // Transport reads (playback state, play mode, now playing) must
        // come from the GROUP COORDINATOR when this player is a follower
        // in a multi-room zone group. A follower's AVTransport service
        // returns junk data — empty track metadata, subordinate
        // transport state — because the real queue/stream is owned by
        // the coordinator. Volume and mute stay per-speaker; those are
        // RenderingControl-level and Sonos models them per player.
        //
        // `transportTarget` returns the player's own host:port for
        // standalone speakers and for speakers that are ALREADY the
        // coordinator, so this is always safe to call.
        let transport = transportTarget(for: player)
        if transport.host != player.host {
            print("[sonos.refresh] \(player.displayName): reading transport state from coordinator \(transport.host):\(transport.port)")
        }

        // --- Core reads (drive isReachable) ---

        var state: PlaybackState?
        do {
            state = try await soap.getPlaybackState(host: transport.host, port: transport.port)
        } catch {
            firstError = error
        }

        var volume: Int?
        do {
            volume = try await soap.getVolume(host: player.host, port: player.port)
        } catch {
            firstError = firstError ?? error
        }

        var muted: Bool?
        do {
            muted = try await soap.getMute(host: player.host, port: player.port)
        } catch {
            firstError = firstError ?? error
        }

        // --- Secondary reads (cosmetic; failures never flip reachability) ---

        // Play mode (shuffle + repeat). Older Sonos firmwares sometimes
        // return NORMAL for line-in / airplay streams — we still want to
        // publish shuffle=false/repeat=off in that case so the buttons
        // render as "off" instead of disabled.
        var playMode: String?
        do {
            playMode = try await soap.getPlayMode(host: transport.host, port: transport.port)
        } catch {
            // Swallow secondary failures so a missing/unimplemented action
            // on older firmware can't bubble up as a "Sonos is broken"
            // banner while core reads were fine.
        }

        // Now playing. Sonos returns an empty snapshot when nothing is
        // loaded; we only publish a nowPlaying capability if we got at
        // least one non-nil field, otherwise the UI would flash an empty
        // title card between tracks.
        var track: SonosSOAPClient.TrackSnapshot?
        do {
            track = try await soap.getPositionInfo(host: transport.host, port: transport.port)
        } catch {
            // Same reason as playMode above.
        }

        // Group volume. Only meaningful when this player is a member of
        // a multi-room zone group that we've already detected during
        // rebuild (`existing.speakerGroup != nil`). We route through
        // `transportTarget` so a follower-viewed refresh still hits the
        // coordinator — `GroupRenderingControl::GetGroupVolume` faults
        // on followers and only returns useful data from the
        // coordinator's /MediaRenderer/GroupRenderingControl endpoint.
        //
        // This is a SECONDARY read: a failure doesn't flip reachability
        // and doesn't stomp prior state. The UI hides the group-volume
        // slider when nil, so missing data degrades cleanly to just
        // showing per-speaker sliders instead of the group master.
        //
        // We deliberately don't gate on `isCoordinator` here — every
        // member reading via transportTarget reads the SAME coordinator
        // and gets the SAME value, which means the UI can source
        // groupVolume off whichever accessory is currently on-screen
        // without needing a cross-accessory lookup.
        var groupVolume: Int?
        if accessories.first(where: { $0.id.nativeID == player.nativeID })?.speakerGroup != nil {
            do {
                groupVolume = try await soap.getGroupVolume(
                    host: transport.host, port: transport.port
                )
            } catch {
                // Swallow — secondary read, and old firmware / solo-
                // promoted speakers can fault here without meaning
                // anything is actually broken.
            }
        }

        guard let index = accessories.firstIndex(where: { $0.id.nativeID == player.nativeID }) else {
            return
        }
        let existing = accessories[index]

        // Reachability policy: at least one core read must have succeeded
        // for THIS cycle to prove the speaker is online. If all three core
        // reads failed, preserve whatever reachability the speaker had
        // before — that avoids one bad cycle (transient Wi-Fi hiccup,
        // player rebooting) marking a working speaker offline. Only
        // once the speaker is definitively a no-show across cycles does
        // the UI actually drop to offline.
        let coreSucceeded = (state != nil) || (volume != nil) || (muted != nil)
        let reachable = coreSucceeded ? true : existing.isReachable

        var caps: [Capability] = []
        if let state { caps.append(.playback(state: state)) }
        if let volume { caps.append(.volume(percent: volume)) }
        if let muted { caps.append(.mute(isMuted: muted)) }
        if let playMode {
            let (shuffle, repeatMode) = SonosPlayMode.parse(playMode)
            caps.append(.shuffle(isOn: shuffle))
            caps.append(.repeatMode(repeatMode))
        }
        if let track, track.title != nil || track.artist != nil || track.album != nil {
            // Resolve the album-art relative path ("/getaa?s=1&u=...") against
            // the SAME host we pulled the metadata from. For standalone
            // players that's the player itself; for a follower in a
            // zone group that's the coordinator (`transport.host`).
            // Sonos' `/getaa` endpoint serves art for the session
            // whose ID is embedded in the `s=` query parameter, and
            // those session IDs are coordinator-scoped — so asking the
            // follower to serve an art URL that was generated against
            // the coordinator's queue returns 404. Using the same host
            // as the source avoids that whole class of confusion.
            let coverURL: URL? = {
                guard let rel = track.albumArtRelativePath, !rel.isEmpty else { return nil }
                let hostForURL = transport.host.contains(":") ? "[\(transport.host)]" : transport.host
                return URL(string: "http://\(hostForURL):\(transport.port)\(rel)")
            }()
            caps.append(.nowPlaying(NowPlaying(
                title: track.title,
                artist: track.artist,
                album: track.album,
                coverArtURL: coverURL
            )))
        } else if let existingNowPlaying = existing.capability(of: .nowPlaying) {
            // Secondary read failed (or returned empty) — keep the previous
            // snapshot so the detail view doesn't suddenly drop to a "Nothing
            // Playing" card mid-track. The next successful cycle will refresh
            // it in place.
            caps.append(existingNowPlaying)
        }

        // Fold the freshly-read group volume into whatever
        // SpeakerGroupMembership we already built during rebuild. If
        // the read failed we preserve the prior value (so the slider
        // doesn't yank to zero mid-drag just because one cycle
        // timed out). If existing.speakerGroup is nil (standalone)
        // we carry nil through — there's no group to describe.
        let updatedSpeakerGroup: SpeakerGroupMembership? = existing.speakerGroup.map { prior in
            SpeakerGroupMembership(
                groupID: prior.groupID,
                isCoordinator: prior.isCoordinator,
                otherMemberNames: prior.otherMemberNames,
                groupVolume: groupVolume ?? prior.groupVolume
            )
        }

        accessories[index] = Accessory(
            id: existing.id,
            name: existing.name,
            category: .speaker,
            roomID: existing.roomID,
            isReachable: reachable,
            capabilities: caps,
            // Preserve the grouping metadata attached during rebuild —
            // a status refresh has nothing to say about topology and
            // must not clobber it, otherwise every refresh cycle would
            // flip bonded-set tiles back to a flat layout.
            groupedParts: existing.groupedParts,
            speakerGroup: updatedSpeakerGroup
        )

        // Surface the first CORE-read failure (if any). Secondary reads
        // are intentionally excluded so they can't spam the Connections
        // screen with noise from actions older firmwares don't implement.
        // We also don't clear `lastError` on the success path here —
        // that's handled by `refresh()`/`onChange` so a transient 1-speaker
        // hiccup doesn't wipe a real ATS or permission error off the
        // screen before the user can read it.
        if let firstError, lastError == nil {
            lastError = "\(player.displayName): \((firstError as? LocalizedError)?.errorDescription ?? firstError.localizedDescription)"
        }
    }

    // MARK: - Mapping

    private func rebuildAccessories(
        from players: [SonosDiscoveredPlayer],
        topology: SonosTopology?
    ) {
        // Keep the prior capability snapshot when an accessory is still
        // present so the UI doesn't flicker empty during a re-discovery.
        let prior = Dictionary(uniqueKeysWithValues: accessories.map { ($0.id.nativeID, $0) })

        // ------------------------------------------------------------
        // Step 1: Derive grouping metadata from topology (if we have it).
        //
        // Output of this step:
        //   • `metadata[host]` — (bonded parts, casual group membership)
        //     to attach to the top-level Accessory for that Bonjour host
        //   • `hiddenSatelliteHosts` — hosts we should DROP from the
        //     top-level list entirely because they're bonded sub/rear
        //     satellites of another player
        //
        // When topology is nil (old firmware, fetch failed, first
        // callback before the fetch returned), both sets are empty
        // and we fall through to the flat per-player rendering.
        // ------------------------------------------------------------

        var metadata: [String: (groupedParts: [String]?, membership: SpeakerGroupMembership?)] = [:]
        var hiddenSatelliteHosts: Set<String> = []

        print("[sonos.rebuild] players=\(players.count) topology=\(topology == nil ? "nil" : "\(topology!.zoneGroups.count) groups")")

        if let topology {
            for group in topology.zoneGroups {
                // Visible members only — `SonosTopologyParser` already
                // filters Invisible=1 entries, but we re-guard here
                // so this function is robust if the parser ever
                // relaxes that rule.
                let visibleMembers = group.members

                for member in visibleMembers {
                    // ---- Bonded home-theater fold-in ----
                    // If the member has `<Satellite>` children, it's a
                    // bonded set (Arc + Sub + rears, stereo pair, etc.).
                    // Collect display labels for the bonded-parts row
                    // and mark every satellite host as hidden.
                    var groupedPartLabels: [String] = []
                    if !member.satellites.isEmpty {
                        // Lead with the main speaker's zone name as
                        // the "anchor" row — the user sees "Family
                        // Room", "Sub", "Rear Left", "Rear Right" at
                        // a glance. Using the zone name rather than a
                        // model name (which we don't reliably have)
                        // keeps the label grounded in something the
                        // user recognises from the Sonos app.
                        groupedPartLabels.append(member.zoneName)
                        for sat in member.satellites {
                            groupedPartLabels.append(sat.displayLabel)
                            if let host = sat.locationHost {
                                hiddenSatelliteHosts.insert(host)
                            }
                        }
                    }

                    // ---- Casual zone group overlay ----
                    // Only surface membership when >1 visible room is in
                    // this group. A single-member group means "playing
                    // alone" and has no overlay to render.
                    var membership: SpeakerGroupMembership?
                    if visibleMembers.count > 1 {
                        let otherNames = visibleMembers
                            .filter { $0.uuid != member.uuid }
                            .map(\.zoneName)
                        membership = SpeakerGroupMembership(
                            groupID: group.groupID,
                            isCoordinator: member.uuid == group.coordinatorUUID,
                            otherMemberNames: otherNames
                        )
                    }

                    if let host = member.locationHost {
                        metadata[host] = (
                            groupedParts: groupedPartLabels.isEmpty ? nil : groupedPartLabels,
                            membership: membership
                        )
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // Step 2: Walk the Bonjour-discovered players, filtering out
        // bonded satellites and attaching grouping metadata to the
        // survivors.
        // ------------------------------------------------------------

        print("[sonos.rebuild] hiddenSatelliteHosts=\(hiddenSatelliteHosts.sorted())")
        print("[sonos.rebuild] metadata keys=\(metadata.keys.sorted())")
        for (host, meta) in metadata {
            let gp = meta.groupedParts?.joined(separator: ",") ?? "nil"
            let mbr = meta.membership.map { "[\($0.isCoordinator ? "coord" : "member")]+\($0.otherMemberNames.count)" } ?? "nil"
            print("[sonos.rebuild]   \(host): parts=[\(gp)] membership=\(mbr)")
        }

        // ------------------------------------------------------------
        // Step 2.5: Synthesize one Sonos "room" per unique visible
        // player display name, so every speaker has a roomID to point
        // at. Sonos has no native room concept — the zone name ("Den",
        // "Kitchen", "Family Room") IS the room label — so we derive
        // rooms by dedupe-ing player names and building a stable
        // room ID from the lowercased+normalized name.
        //
        // Why derive from display name rather than each player's
        // individual UUID: two stereo-paired speakers look like one
        // "Kitchen" zone to the user, and we already collapse bonded
        // satellites via the hiddenSatelliteHosts set, so both ends
        // land under the same room.
        //
        // The UI layer (AllRoomsView / RoomDetailView) unifies these
        // rooms with same-named rooms from OTHER providers (HomeKit,
        // SmartThings) so a "Den" Sonos speaker shows up alongside
        // "Den" HomeKit lights as a single virtual room tile.
        // ------------------------------------------------------------

        var derivedRooms: [Room] = []
        var roomIDByName: [String: String] = [:]
        for player in players where !hiddenSatelliteHosts.contains(player.host) {
            let normalized = player.displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()
            if roomIDByName[key] != nil { continue }
            // Room ID scheme: "sonos.room.<slug>" — stable across
            // refreshes because it's derived from the zone name, not
            // a random UUID. Slug rule: lowercase, spaces → dashes,
            // strip characters outside a-z/0-9/dash.
            let slug = key
                .replacingOccurrences(of: " ", with: "-")
                .unicodeScalars
                .filter { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-").contains($0) }
                .map(String.init)
                .joined()
            let roomID = "sonos.room.\(slug)"
            roomIDByName[key] = roomID
            derivedRooms.append(
                Room(id: roomID,
                     name: normalized,
                     homeID: SonosProvider.syntheticHomeID,
                     provider: .sonos)
            )
        }
        rooms = derivedRooms.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        print("[sonos.rebuild] derived rooms: \(rooms.map(\.name))")

        accessories = players.compactMap { player -> Accessory? in
            // Bonded satellites never appear as their own tile. They're
            // only visible as entries in the parent member's
            // `groupedParts` array (rendered on the coordinator tile).
            if hiddenSatelliteHosts.contains(player.host) { return nil }

            let meta = metadata[player.host]

            // Resolve this speaker's roomID from the zone-name map.
            // Using the same normalization rule as the derived-rooms
            // pass above keeps the two sides symmetric.
            let normalized = player.displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let roomID = roomIDByName[normalized.lowercased()]

            if let existing = prior[player.nativeID] {
                // Preserve the existing capability snapshot + reachable
                // state so a pure topology re-rebuild doesn't blink the
                // volume slider or flip a healthy speaker to offline.
                // Room assignment is freshly re-derived every rebuild
                // (not carried over from `existing.roomID`) so a zone
                // rename in the Sonos app eventually retargets the
                // accessory instead of pinning it to the old room.
                return Accessory(
                    id: existing.id,
                    name: player.displayName,
                    category: .speaker,
                    roomID: roomID,
                    isReachable: existing.isReachable,
                    capabilities: existing.capabilities,
                    groupedParts: meta?.groupedParts,
                    speakerGroup: meta?.membership
                )
            } else {
                return Accessory(
                    id: AccessoryID(provider: .sonos, nativeID: player.nativeID),
                    name: player.displayName,
                    category: .speaker,
                    roomID: roomID,
                    // Optimistic — flipped to real value on first
                    // status read. Starting at `true` prevents the
                    // initial "Unreachable" badge flicker while the
                    // three core SOAP reads are in flight.
                    isReachable: true,
                    capabilities: [],
                    groupedParts: meta?.groupedParts,
                    speakerGroup: meta?.membership
                )
            }
        }
    }
}

// MARK: - SonosPlayMode
//
// Sonos' AVTransport service represents shuffle + repeat as a SINGLE
// string ("PlayMode") with exactly six legal values, instead of two
// independent flags. Our unified model exposes them as two separate
// capabilities (`.shuffle` and `.repeatMode`), so this helper is the
// only place that knows about the cross-product.
//
// The six legal values (per the UPnP AVTransport spec + Sonos' own docs):
//   NORMAL              — shuffle off, repeat off
//   REPEAT_ALL          — shuffle off, repeat all
//   REPEAT_ONE          — shuffle off, repeat one
//   SHUFFLE_NOREPEAT    — shuffle on,  repeat off
//   SHUFFLE             — shuffle on,  repeat all   (historical alias;
//                         Sonos treats bare `SHUFFLE` as "shuffle + repeat all")
//   SHUFFLE_REPEAT_ONE  — shuffle on,  repeat one
//
// `parse` is tolerant: any unexpected string collapses to (false, .off),
// which is the same thing Sonos returns for line-in sources anyway.

enum SonosPlayMode {
    static func string(shuffle: Bool, repeatMode: RepeatMode) -> String {
        switch (shuffle, repeatMode) {
        case (false, .off): return "NORMAL"
        case (false, .all): return "REPEAT_ALL"
        case (false, .one): return "REPEAT_ONE"
        case (true,  .off): return "SHUFFLE_NOREPEAT"
        case (true,  .all): return "SHUFFLE"
        case (true,  .one): return "SHUFFLE_REPEAT_ONE"
        }
    }

    static func parse(_ raw: String) -> (shuffle: Bool, repeatMode: RepeatMode) {
        switch raw {
        case "NORMAL":             return (false, .off)
        case "REPEAT_ALL":         return (false, .all)
        case "REPEAT_ONE":         return (false, .one)
        case "SHUFFLE_NOREPEAT":   return (true,  .off)
        case "SHUFFLE":            return (true,  .all)
        case "SHUFFLE_REPEAT_ONE": return (true,  .one)
        default:                   return (false, .off)
        }
    }
}

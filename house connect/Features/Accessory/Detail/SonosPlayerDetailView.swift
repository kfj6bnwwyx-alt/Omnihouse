//
//  SonosPlayerDetailView.swift
//  house connect
//
//  Bespoke detail screen for Sonos speakers. Matches Pencil node `ypxJT`:
//  a large album-art card with track metadata, a row of five transport
//  controls (shuffle / previous / play-pause / next / repeat), a progress
//  bar, a volume slider, and a "Speaker Group" list below.
//
//  This screen reads/writes every media capability the Sonos provider
//  emits: playback, volume, mute, nowPlaying (with cover art), shuffle,
//  and repeatMode. Each control disables itself if the underlying
//  capability is unavailable rather than disappearing, so the layout
//  stays stable when the speaker transitions between streams that
//  report different subsets (e.g. line-in has no shuffle/repeat).
//

import SwiftUI

struct SonosPlayerDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    @State private var errorMessage: String?
    /// Top-of-screen toast banner (Pencil `co524` / `pyUlJ`). Replaces
    /// the SwiftUI `.alert` for transient feedback on group add /
    /// remove / connection errors. The alert is still kept around as
    /// a fallback for unexpected provider errors — toasts are for
    /// "expected, user-initiated" outcomes.
    @State private var toast: Toast?
    /// Slider-drag draft for the per-speaker "Volume" card at the top
    /// of the screen (this speaker's own RenderingControl value).
    @State private var volumeDraft: Double?
    /// Slider-drag draft for the GROUP-wide "Group Volume" slider in
    /// the speaker group card. Scoped to the value being committed,
    /// cleared as soon as the optimistic refresh lands — same shape
    /// as `volumeDraft` so the slider thumb doesn't jitter between
    /// the user's finger position and the provider's stale read.
    @State private var groupVolumeDraft: Double?
    /// Slider-drag drafts for EACH member speaker inside the group
    /// card. Keyed by AccessoryID so multiple sliders can be dragged
    /// without trampling each other. An entry is cleared the moment
    /// its `send(...)` call returns, at which point the slider snaps
    /// back to the live `accessory.volumePercent`.
    @State private var memberVolumeDrafts: [AccessoryID: Double] = [:]
    /// Debouncer for the group-volume slider. Sonos' SOAP endpoint
    /// doesn't love being hit every frame while the user drags — a
    /// rapid sequence of SetGroupVolume writes can return 500s. This
    /// gate coalesces rapid updates into ~60ms buckets so the last
    /// value a user stopped on wins. Per-speaker sliders use their
    /// own debouncer below.
    @State private var groupVolumeDebounce: Task<Void, Never>?
    /// Debouncers for per-member sliders, keyed by AccessoryID so a
    /// drag on Kitchen doesn't cancel a drag on Den.
    @State private var memberVolumeDebounces: [AccessoryID: Task<Void, Never>] = [:]
    /// Presents the modal room picker (Pencil `g00bw`). Replaces the
    /// old inline "Group with…" list + "Leave group" button with a
    /// single sheet full of toggles and a "Play on N Rooms" CTA.
    @State private var showingRoomPicker = false

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    /// Other Sonos speakers that this player could be grouped WITH —
    /// i.e. everything except itself, not already in the same zone
    /// group, and also a speaker (we want `.speaker` by category
    /// rather than `isMediaPlayer` so this list is populated on first
    /// render instead of waiting for the status sweep to land).
    ///
    /// Ordered alphabetically so the list is stable between refreshes.
    ///
    /// Earlier versions of this helper filtered by `roomID == accessory.roomID`
    /// — which was always empty on Sonos, because Sonos providers
    /// never populate `roomID` (Sonos has no native room concept).
    /// That bug made the Speaker Group card read "No other Sonos
    /// speakers in this room" for every user, every time, forever.
    /// Switching to topology-based zone-group membership fixes it.
    private var groupCandidates: [Accessory] {
        guard let accessory else { return [] }
        let myGroupID = accessory.speakerGroup?.groupID
        var result: [Accessory] = []
        for other in registry.allAccessories {
            if other.id == accessory.id { continue }
            if other.id.provider != .sonos { continue }
            if other.category != .speaker { continue }
            if let myGroupID, other.speakerGroup?.groupID == myGroupID {
                continue
            }
            result.append(other)
        }
        result.sort { a, b in
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return result
    }

    /// The other visible rooms currently in the SAME zone group as this
    /// speaker — used for the "playing together" section of the card.
    /// Empty when playing alone. Looked up off the registry (not the
    /// `speakerGroup.otherMemberNames` string list) so we can surface
    /// each member as a real tappable `Accessory` row.
    private var currentGroupMembers: [Accessory] {
        guard let accessory, let group = accessory.speakerGroup else { return [] }
        var result: [Accessory] = []
        for other in registry.allAccessories {
            if other.id == accessory.id { continue }
            if other.id.provider != .sonos { continue }
            if other.category != .speaker { continue }
            if other.speakerGroup?.groupID == group.groupID {
                result.append(other)
            }
        }
        result.sort { a, b in
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return result
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(spacing: 20) {
                        DeviceDetailHeader(
                            title: accessory.name,
                            subtitle: roomName,
                            isOn: accessory.isOn,
                            onTogglePower: { on in
                                Task { await send(.setPower(on), accessory: accessory) }
                            }
                        )
                        .padding(.top, 8)

                        albumArtCard(for: accessory)
                        transportRow(for: accessory)
                        progressCard(for: accessory)
                        volumeCard(for: accessory)
                        speakerGroupCard(for: accessory)
                        RemoveDeviceSection(accessoryID: accessoryID)
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "Speaker unavailable",
                    systemImage: "hifispeaker.slash"
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Operation failed",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }),
               actions: { Button("OK") { errorMessage = nil } },
               message: { Text(errorMessage ?? "") })
        .toast($toast)
        .sheet(isPresented: $showingRoomPicker) {
            if let accessory {
                SonosRoomPickerSheet(
                    anchor: accessory,
                    currentMembers: currentGroupMembers,
                    candidates: groupCandidates,
                    onApply: { additions, removals in
                        await applyRoomPickerDiff(
                            anchor: accessory,
                            additions: additions,
                            removals: removals
                        )
                    },
                    onScanAgain: {
                        // Kicks a targeted refresh on the anchor so
                        // the Sonos provider re-reads its zone-group
                        // topology. Not a full rediscovery — that's
                        // TODO once SonosProvider exposes a
                        // `rediscover()` API — but enough to surface
                        // any speakers that just came online.
                        if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                            await sonos.refreshAccessory(accessory.id)
                        }
                    }
                )
                .presentationDetents([.large])
            }
        }
        // Polling loop: while this detail view is visible, re-read
        // transport + nowPlaying for the viewed speaker every 3s so
        // external changes (someone hits Play in the Sonos app, the
        // track auto-advances, another room joins the group) surface
        // in the UI within a poll cycle instead of requiring a manual
        // refresh or app restart.
        //
        // `.task(id:)` keyed on `accessoryID` so navigating between
        // speakers tears the old polling task down and starts a fresh
        // one against the new ID — otherwise SwiftUI would reuse the
        // in-flight task from the previous speaker.
        //
        // The loop is cancellation-safe: `Task.isCancelled` checks
        // happen before AND after the sleep, so a quick navigate-away
        // doesn't leave a ghost poll running for a whole cycle.
        // We only poll when there's a live provider to talk to —
        // other AccessoryProviders don't need this (HomeKit surfaces
        // its own change notifications; SmartThings polls internally),
        // so the downcast here is deliberate and scoped to Sonos.
        .task(id: accessoryID) {
            guard let sonos = registry.provider(for: .sonos) as? SonosProvider else {
                return
            }
            while !Task.isCancelled {
                await sonos.refreshAccessory(accessoryID)
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: - Album art card

    private func albumArtCard(for accessory: Accessory) -> some View {
        let np = accessory.nowPlaying
        let title = np?.title ?? "Nothing Playing"
        let artist = np?.artist ?? (accessory.playbackState == .playing ? "Unknown Artist" : "—")
        let album = np?.album

        return VStack(spacing: 16) {
            // Album art. When Sonos is actually playing something with a
            // cover URL we pull it straight off the player over its local
            // HTTP endpoint (set by SonosProvider.refreshStatus). AsyncImage
            // caches per-URL, so scrolling in/out of the detail view
            // doesn't re-fetch.
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.color.iconChipFill)
                    .aspectRatio(1, contentMode: .fit)

                if let artURL = np?.coverArtURL {
                    AsyncImage(url: artURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        case .failure:
                            // Network hiccup or 404 on the getaa endpoint —
                            // fall back to the music-note so the card
                            // doesn't read as "broken".
                            Image(systemName: "music.note")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(Theme.color.iconChipGlyph)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            Image(systemName: "music.note")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(Theme.color.iconChipGlyph)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(Theme.color.iconChipGlyph)
                }
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(artist)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.color.subtitle)
                if let album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.color.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                [title, artist, album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .hcCard(padding: 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing")
    }

    // MARK: - Transport row

    private func transportRow(for accessory: Accessory) -> some View {
        let isPlaying = accessory.playbackState == .playing
        let shuffleOn = accessory.isShuffling ?? false
        let repeatMode = accessory.repeatMode ?? .off

        // Shuffle button is highlighted (primary style) when on. Tap
        // toggles the current state.
        let shuffleStyle: TransportStyle = shuffleOn ? .primary : .secondary

        // Repeat button: off → badge "repeat" glyph, all → highlighted
        // "repeat", one → highlighted "repeat.1". Tap cycles off→all→one→off.
        let nextRepeat: RepeatMode = {
            switch repeatMode {
            case .off: return .all
            case .all: return .one
            case .one: return .off
            }
        }()
        let repeatGlyph = repeatMode == .one ? "repeat.1" : "repeat"
        let repeatStyle: TransportStyle = repeatMode == .off ? .secondary : .primary

        return HStack(spacing: 12) {
            transportButton(system: "shuffle",
                            size: 44,
                            style: shuffleStyle,
                            disabled: !accessory.isReachable || accessory.isShuffling == nil) {
                Task { await send(.setShuffle(!shuffleOn), accessory: accessory) }
            }
            .accessibilityLabel("Shuffle")
            .accessibilityValue(shuffleOn ? "On" : "Off")
            .accessibilityHint(shuffleOn ? "Double tap to turn shuffle off" : "Double tap to turn shuffle on")
            .accessibilityAddTraits(.isToggle)

            transportButton(system: "backward.fill",
                            size: 52,
                            style: .secondary,
                            disabled: !accessory.isReachable) {
                Task { await send(.previous, accessory: accessory) }
            }
            .accessibilityLabel("Previous track")

            transportButton(system: isPlaying ? "pause.fill" : "play.fill",
                            size: 72,
                            style: .primary,
                            disabled: !accessory.isReachable) {
                Task { await send(isPlaying ? .pause : .play, accessory: accessory) }
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            transportButton(system: "forward.fill",
                            size: 52,
                            style: .secondary,
                            disabled: !accessory.isReachable) {
                Task { await send(.next, accessory: accessory) }
            }
            .accessibilityLabel("Next track")

            transportButton(system: repeatGlyph,
                            size: 44,
                            style: repeatStyle,
                            disabled: !accessory.isReachable || accessory.repeatMode == nil) {
                Task { await send(.setRepeatMode(nextRepeat), accessory: accessory) }
            }
            .accessibilityLabel("Repeat")
            .accessibilityValue({
                switch repeatMode {
                case .off: return "Off"
                case .all: return "All"
                case .one: return "One"
                }
            }())
            .accessibilityHint({
                switch repeatMode {
                case .off: return "Double tap to repeat all"
                case .all: return "Double tap to repeat one"
                case .one: return "Double tap to turn repeat off"
                }
            }())
            .accessibilityAddTraits(.isToggle)
        }
        .frame(maxWidth: .infinity)
        .hcCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Transport controls")
    }

    private enum TransportStyle { case primary, secondary }

    private func transportButton(
        system: String,
        size: CGFloat,
        style: TransportStyle,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(style == .primary ? Theme.color.primary : Theme.color.iconChipFill)
                    .frame(width: size, height: size)
                Image(systemName: system)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(style == .primary ? Color.white : Theme.color.iconChipGlyph)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    // MARK: - Progress card (static — no track position in capabilities yet)

    private func progressCard(for accessory: Accessory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(Theme.color.divider)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    // No position data yet → render a short purple nub
                    // just so the bar reads as "progress" visually.
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.color.primary)
                            .frame(width: accessory.playbackState == .playing
                                   ? geo.size.width * 0.33 : 0,
                                   height: 6)
                    }
                    .frame(height: 6)
                }

            HStack {
                Text("—:—")
                Spacer()
                Text("—:—")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.color.muted)
        }
        .hcCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            accessory.playbackState == .playing
                ? "Track progress, playing"
                : "Track progress, no position data available"
        )
    }

    // MARK: - Volume card

    private func volumeCard(for accessory: Accessory) -> some View {
        let liveVolume = accessory.volumePercent.map(Double.init) ?? 0
        let shown = volumeDraft ?? liveVolume
        let muted = accessory.isMuted ?? false

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconChip(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume")
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text(accessory.volumePercent != nil
                         ? "\(Int(shown))%"
                         : "Unavailable")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .monospacedDigit()
                }

                Spacer()

                Button {
                    Task { await send(.setMute(!muted), accessory: accessory) }
                } label: {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(muted ? .white : Theme.color.iconChipGlyph)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(muted ? Theme.color.primary : Theme.color.iconChipFill)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!accessory.isReachable || accessory.isMuted == nil)
                .accessibilityLabel(muted ? "Unmute" : "Mute")
                .accessibilityHint(muted ? "Double tap to unmute speaker" : "Double tap to mute speaker")
            }

            Slider(
                value: Binding(
                    get: { shown },
                    set: { newValue in
                        volumeDraft = newValue
                        Task {
                            await send(.setVolume(Int(newValue.rounded())),
                                       accessory: accessory)
                            // Clear the draft once the provider has picked up
                            // the new value so we go back to the live reading.
                            volumeDraft = nil
                        }
                    }
                ),
                in: 0...100,
                step: 1
            )
            .tint(Theme.color.primary)
            .disabled(!accessory.isReachable || accessory.volumePercent == nil)
            .accessibilityLabel("Volume")
            .accessibilityValue(accessory.volumePercent != nil ? "\(Int(shown)) percent" : "Unavailable")
        }
        .hcCard()
    }

    // MARK: - Speaker group card

    /// Three sections (when grouped):
    ///
    /// 1. **Group Volume** — a single slider bound to the coordinator's
    ///    `GroupRenderingControl::SetGroupVolume`, which scales every
    ///    member's individual volume proportionally. Hidden when solo
    ///    (the top-of-screen `volumeCard` already handles that case).
    /// 2. **Grouped with** — one row per member showing its name and
    ///    its OWN per-speaker volume slider, so the user can trim the
    ///    mix the way Sonos' own app does. The PRIMARY badge follows
    ///    the real coordinator flag, not "the row you're viewing" —
    ///    transport writes go to the coordinator regardless.
    /// 3. **Group with…** — every other visible Sonos speaker that
    ///    isn't already in our zone group. Tapping a row attaches us
    ///    using the "music side wins" rule in the Button closure.
    ///
    /// When solo AND no candidates exist the card renders a single
    /// empty-state row so it never reads as "broken".
    @ViewBuilder
    private func speakerGroupCard(for accessory: Accessory) -> some View {
        let currentMembers = currentGroupMembers
        let candidates = groupCandidates
        let isInGroup = !currentMembers.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speaker Group")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Spacer()
                Text(isInGroup
                     ? "Grouped with \(currentMembers.count)"
                     : "Playing alone")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                isInGroup
                    ? "Speaker group, grouped with \(currentMembers.count) other \(currentMembers.count == 1 ? "speaker" : "speakers")"
                    : "Speaker group, playing alone"
            )

            // Group-volume master. Only rendered when we're actually in
            // a group — solo speakers already have a volume slider at
            // the top of the screen and a second one would be
            // redundant. The value lives on
            // `speakerGroup.groupVolume`, populated by refreshStatus
            // via GroupRenderingControl::GetGroupVolume; nil when
            // the read hasn't run yet or faulted, in which case we
            // just hide the slider rather than pinning it to zero.
            if isInGroup, let groupVolume = accessory.speakerGroup?.groupVolume {
                groupVolumeRow(for: accessory, liveGroupVolume: groupVolume)
                Divider().overlay(Theme.color.divider)
            }

            // Current group section — only rendered when we're actually
            // grouped with someone else. The anchor row (this speaker)
            // always appears first so the user can orient themselves,
            // but the PRIMARY badge follows the real coordinator flag
            // from `speakerGroup.isCoordinator`, NOT "this speaker".
            // That matters because transport commands always route to
            // the coordinator — if we labeled the viewed speaker as
            // "PRIMARY" when it wasn't, the user would see "Play"
            // fail with a confusing "nothing queued" error (the
            // actual coordinator IS empty) while the badge insisted
            // they were the one in charge.
            if isInGroup {
                let weAreCoordinator = accessory.speakerGroup?.isCoordinator == true
                VStack(spacing: 12) {
                    memberVolumeRow(
                        for: accessory,
                        isAnchor: true,
                        isPrimary: weAreCoordinator
                    )
                    ForEach(currentGroupMembers) { other in
                        let othersCoordinator = other.speakerGroup?.isCoordinator == true
                        memberVolumeRow(
                            for: other,
                            isAnchor: false,
                            isPrimary: othersCoordinator
                        )
                    }
                }
            }

            // "Select Rooms" CTA — replaces the old inline candidate
            // list + "Leave group" button with a single modal sheet
            // (Pencil `g00bw`). The sheet presents every Sonos speaker
            // as a toggle, preseeded with the current group membership,
            // and fires a batched join/leave diff on apply. Always
            // shown, even when there are no other Sonos speakers,
            // because we still want a clear entry point — the sheet
            // itself handles the empty state.
            Button {
                showingRoomPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hifispeaker.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isInGroup ? "Edit Rooms" : "Select Rooms")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.color.primary)
                )
            }
            .buttonStyle(.plain)
            .disabled(!accessory.isReachable || (candidates.isEmpty && !isInGroup))
            .opacity(accessory.isReachable && (!candidates.isEmpty || isInGroup) ? 1 : 0.5)
            .padding(.top, isInGroup ? 4 : 0)
            .accessibilityLabel(isInGroup ? "Edit rooms in speaker group" : "Select rooms to group with")
            .accessibilityHint("Opens room selection sheet")

            if !isInGroup && candidates.isEmpty {
                Text("No other Sonos rooms available to group with.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.muted)
                    .padding(.vertical, 4)
            }
        }
        .hcCard()
    }

    // MARK: - Room picker diff

    /// Applies the toggle delta from `SonosRoomPickerSheet`. Split into
    /// removals first, then additions, so a user who (say) toggled
    /// Kitchen off and Bedroom on doesn't briefly end up with both in
    /// the group. Each command goes through the existing `send` path
    /// so errors surface in the same alert the rest of the screen
    /// uses.
    ///
    /// `additions` are non-anchor speakers that should END UP in the
    /// anchor's group but aren't yet. `removals` are speakers that
    /// were in the anchor's group (including the anchor itself) and
    /// should leave.
    ///
    /// Coordinator selection for first-time grouping uses the same
    /// "music side wins" rule as the old inline Join button: the
    /// speaker with loaded media becomes / stays the coordinator,
    /// tie goes to the anchor. For subsequent additions the anchor's
    /// existing group is the coordinator, so everyone joins it.
    private func applyRoomPickerDiff(
        anchor: Accessory,
        additions: [Accessory],
        removals: [Accessory]
    ) async {
        var failedName: String?

        // Phase 1 — removals. Leave-group is a pointwise op on the
        // leaving speaker, so order doesn't matter.
        for leaver in removals {
            let ok = await sendSilently(.leaveSpeakerGroup, accessory: leaver)
            if !ok { failedName = leaver.name }
        }

        guard !additions.isEmpty else {
            // Removals-only path — fire a toast based on what just happened.
            if let failedName {
                toast = .error("\(failedName) disconnected")
            } else if removals.count == 1 {
                toast = .success("\(removals[0].name) removed from group")
            } else if removals.count > 1 {
                toast = .success("\(removals.count) rooms removed")
            }
            return
        }

        // Phase 2 — additions. If the anchor is already in a group
        // (i.e. currentGroupMembers was non-empty before the diff
        // started, or we're keeping at least one existing member),
        // everyone joins the anchor directly. Otherwise we fall back
        // to the music-side-wins rule on the FIRST addition to pick
        // a coordinator, then subsequent additions join that
        // coordinator.
        let anchorAlreadyCoordinating =
            (anchor.speakerGroup != nil) &&
            !removals.contains(where: { $0.id == anchor.id })

        if anchorAlreadyCoordinating {
            for joiner in additions {
                let ok = await sendSilently(.joinSpeakerGroup(target: anchor.id),
                                            accessory: joiner)
                if !ok { failedName = joiner.name }
            }
            emitAdditionToast(additions: additions, failedName: failedName)
            return
        }

        // First addition decides the coordinator via music-side-wins.
        // Same two-headed logic as the old inline Join button:
        //   • anchor has media → candidate joins anchor
        //   • only candidate has media → anchor joins candidate,
        //     candidate becomes the new coordinator
        //   • neither has media → anchor wins (user's focal speaker)
        guard let firstAddition = additions.first else {
            emitAdditionToast(additions: additions, failedName: failedName)
            return
        }
        let anchorHasMedia = anchor.hasLoadedMedia
        let candidateHasMedia = firstAddition.hasLoadedMedia
        let coordinator: Accessory
        switch (anchorHasMedia, candidateHasMedia) {
        case (true, _), (false, false):
            coordinator = anchor
            let ok = await sendSilently(.joinSpeakerGroup(target: anchor.id),
                                        accessory: firstAddition)
            if !ok { failedName = firstAddition.name }
        case (false, true):
            coordinator = firstAddition
            let ok = await sendSilently(.joinSpeakerGroup(target: firstAddition.id),
                                        accessory: anchor)
            if !ok { failedName = anchor.name }
        }

        // Remaining additions join whichever speaker we just picked
        // as coordinator. (Skip firstAddition — already handled.)
        for joiner in additions.dropFirst() {
            if joiner.id == coordinator.id { continue }
            let ok = await sendSilently(.joinSpeakerGroup(target: coordinator.id),
                                        accessory: joiner)
            if !ok { failedName = joiner.name }
        }

        emitAdditionToast(additions: additions, failedName: failedName)
    }

    /// Single-message toast for the additions pass. Prefers the
    /// error toast if anything failed, otherwise renders a success
    /// banner with the added room count. Copy matches Pencil `co524`
    /// ("Bedroom added to group") for the single-add case and
    /// falls back to a count for multi-add.
    private func emitAdditionToast(additions: [Accessory], failedName: String?) {
        if let failedName {
            toast = .error("\(failedName) disconnected")
            return
        }
        guard !additions.isEmpty else { return }
        if additions.count == 1 {
            toast = .success("\(additions[0].name) added to group")
        } else {
            toast = .success("\(additions.count) rooms added to group")
        }
    }

    /// The group-wide master slider. Writes go to `setGroupVolume`
    /// which SonosProvider routes to the zone-group coordinator via
    /// `transportTarget` — Sonos then scales every member's
    /// RenderingControl value proportionally so the relative mix is
    /// preserved. Matches Pencil node `BUOyt`'s "Group Volume 65%"
    /// row.
    ///
    /// `liveGroupVolume` is the value most recently read from
    /// `GroupRenderingControl::GetGroupVolume`; the slider binds to a
    /// draft so the thumb doesn't flicker back to a stale value mid-
    /// drag. Draft is cleared on the trailing edge of the debounce
    /// task when the provider's optimistic refresh lands.
    private func groupVolumeRow(for accessory: Accessory, liveGroupVolume: Int) -> some View {
        let shown = groupVolumeDraft ?? Double(liveGroupVolume)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
                Text("Group Volume")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Spacer()
                Text("\(Int(shown))%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color.subtitle)
            }
            Slider(
                value: Binding(
                    get: { shown },
                    set: { newValue in
                        groupVolumeDraft = newValue
                        // Debounce so a drag doesn't flood the
                        // coordinator with SetGroupVolume writes —
                        // Sonos returns 500s under load. 60ms is
                        // enough to coalesce a continuous drag into
                        // roughly 15 writes/sec and still feels
                        // instant to the user's ear.
                        groupVolumeDebounce?.cancel()
                        groupVolumeDebounce = Task {
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            guard !Task.isCancelled else { return }
                            await send(.setGroupVolume(Int(newValue.rounded())),
                                       accessory: accessory)
                            // Once the refresh cycle lands we want
                            // the slider to read the live value
                            // again. Clearing the draft inside the
                            // task means a NEW drag can immediately
                            // overwrite it without racing.
                            if groupVolumeDraft == newValue {
                                groupVolumeDraft = nil
                            }
                        }
                    }
                ),
                in: 0...100,
                step: 1
            )
            .tint(Theme.color.primary)
            .disabled(!accessory.isReachable)
            .accessibilityLabel("Group volume")
            .accessibilityValue("\(Int(shown)) percent")
        }
    }

    /// One row per group member with its own per-speaker volume
    /// slider, a name label, and (on the coordinator) a PRIMARY
    /// badge. Writes go to `.setVolume` on THIS member's accessory,
    /// not the anchor — SonosProvider's execute routes to the
    /// member's own host for RenderingControl, so per-speaker volume
    /// stays per-speaker even when the detail view is anchored on a
    /// different member.
    ///
    /// `isAnchor` is true for the speaker whose detail view this is
    /// (gets an extra subtitle "This speaker"). The UI treats the
    /// anchor exactly like any other member for slider purposes —
    /// no special-casing — so the user can drag Kitchen's slider
    /// while viewing Den's screen and it still works.
    private func memberVolumeRow(
        for member: Accessory,
        isAnchor: Bool,
        isPrimary: Bool
    ) -> some View {
        let liveVolume = member.volumePercent.map(Double.init) ?? 0
        let shown = memberVolumeDrafts[member.id] ?? liveVolume
        let hasVolumeReading = member.volumePercent != nil
        let isOffline = !member.isReachable
        let subtitle: String = {
            if isOffline { return "Disconnected" }
            if isAnchor {
                return isPrimary ? "This speaker · Group leader" : "This speaker"
            }
            if isPrimary { return "Group leader" }
            return member.isOn == true ? "Playing" : "Idle"
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Glyph swaps to a disconnected speaker icon when
                // offline — Pencil `pyUlJ` uses a slashed speaker
                // in red to make the state unambiguous at a glance.
                IconChip(
                    systemName: isOffline ? "hifispeaker.slash.fill" : "hifispeaker.fill",
                    size: 32,
                    fill: isOffline ? Theme.color.danger.opacity(0.15) : Theme.color.iconChipFill,
                    glyph: isOffline ? Theme.color.danger : Theme.color.iconChipGlyph
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.color.title)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(isOffline ? Theme.color.danger : Theme.color.subtitle)
                }
                Spacer()
                if hasVolumeReading && !isOffline {
                    Text("\(Int(shown))%")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.color.subtitle)
                }
                if isPrimary && !isOffline {
                    Text("PRIMARY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.color.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Theme.color.iconChipFill)
                        )
                }
            }

            // Offline rows swap the volume slider for a Retry /
            // Remove button pair matching Pencil `pyUlJ`. Retry
            // asks SonosProvider to refresh this specific accessory
            // (which will flip `isReachable` back on if the speaker
            // has come back). Remove fires `.leaveSpeakerGroup` so
            // the ghosted row drops out of the group list — it's
            // harmless on an already-disconnected speaker because
            // the UPnP call faults silently and we clean up the
            // local state regardless.
            if isOffline {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            if let sonos = registry.provider(for: .sonos) as? SonosProvider {
                                await sonos.refreshAccessory(member.id)
                            }
                        }
                    } label: {
                        Text("Retry")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.color.primary, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry connection to \(member.name)")

                    Button {
                        Task { await send(.leaveSpeakerGroup, accessory: member) }
                    } label: {
                        Text("Remove")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.color.subtitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.color.divider, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(member.name) from group")
                }
            } else {
                Slider(
                    value: Binding(
                        get: { shown },
                        set: { newValue in
                            memberVolumeDrafts[member.id] = newValue
                            // Per-member debounce keyed on the member's
                            // AccessoryID so each speaker's slider has
                            // its own independent gate — a drag on
                            // Kitchen never cancels a drag on Den.
                            memberVolumeDebounces[member.id]?.cancel()
                            memberVolumeDebounces[member.id] = Task {
                                try? await Task.sleep(nanoseconds: 60_000_000)
                                guard !Task.isCancelled else { return }
                                await send(.setVolume(Int(newValue.rounded())),
                                           accessory: member)
                                // Clear the draft only if no newer drag
                                // has overwritten it — matches the
                                // same guard used in groupVolumeRow.
                                if memberVolumeDrafts[member.id] == newValue {
                                    memberVolumeDrafts.removeValue(forKey: member.id)
                                }
                            }
                        }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(Theme.color.primary)
                .disabled(!hasVolumeReading)
                .accessibilityLabel("\(member.name) volume")
                .accessibilityValue(hasVolumeReading ? "\(Int(shown)) percent" : "Unavailable")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(member.name), \(subtitle)")
    }

    /// Row used inside the "Group with…" candidate list. Styled as a
    /// tap target so it reads as actionable even when the enclosing
    /// Button strips SwiftUI's default chrome.
    private func groupCandidateRow(name: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            IconChip(systemName: "hifispeaker.fill", size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.color.primary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(subtitle)")
        .accessibilityHint("Double tap to add to speaker group")
    }

    // MARK: - Actions

    private func send(_ command: AccessoryCommand, accessory: Accessory) async {
        do {
            try await registry.execute(command, on: accessory.id)
        } catch {
            errorMessage = "\(accessory.name): \(error)"
        }
    }

    /// Variant of `send` used by the room-picker diff flow. Returns
    /// true on success, false on error — but does NOT raise the
    /// blocking alert. The caller aggregates results and emits a
    /// single toast banner at the end so users see "Bedroom added"
    /// (or "Bedroom disconnected") instead of a modal dialog per
    /// command in a batch.
    @discardableResult
    private func sendSilently(_ command: AccessoryCommand, accessory: Accessory) async -> Bool {
        do {
            try await registry.execute(command, on: accessory.id)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Media-state heuristic

private extension Accessory {
    /// Does this speaker currently have a stream / queue loaded?
    ///
    /// Used by the "Group with…" button in the Sonos detail view to
    /// decide which side of a join should become the coordinator —
    /// the speaker with media loaded should lead, so `SetAVTransportURI`
    /// doesn't wipe a live stream by redirecting it at an empty
    /// x-rincon target.
    ///
    /// Heuristic: present a nowPlaying snapshot with at least one
    /// populated field, OR be in a non-idle transport state
    /// (playing, paused mid-track, transitioning). We intentionally
    /// treat `.paused` as "has media" — a paused song still has a
    /// loaded queue behind it, and rejoining the group should
    /// resume from that same queue.
    ///
    /// Scoped file-locally because this heuristic is only meaningful
    /// for Sonos' grouping flow; other providers would define
    /// "active media" differently.
    var hasLoadedMedia: Bool {
        if let np = nowPlaying,
           np.title != nil || np.artist != nil || np.album != nil {
            return true
        }
        switch playbackState {
        case .playing, .paused, .transitioning:
            return true
        default:
            return false
        }
    }
}

// MARK: - SonosRoomPickerSheet (Pencil g00bw)

/// Modal sheet that replaces the old inline Join/Leave list in
/// `SonosPlayerDetailView.speakerGroupCard`. Matches Pencil node
/// `g00bw`: a "Select Rooms" title, a now-playing card, a list of
/// every Sonos speaker with a toggle (preseeded with the anchor's
/// current group membership), and a primary "Play on N Rooms" CTA
/// at the bottom that diffs the toggle state and hands the
/// additions/removals back to the detail view.
///
/// The sheet is purely presentational — it builds a diff and calls
/// `onApply`, but it's `SonosPlayerDetailView.applyRoomPickerDiff`
/// that decides coordinator direction (music-side-wins) and fires
/// the actual provider commands. That split keeps the sheet's
/// selection logic trivially unit-testable later if we add a test
/// target.
///
/// Offline rows render with a red "Speaker offline" subtitle and
/// are disabled (`woiK9`-ish). A proper "Last seen Xh ago" + Retry
/// affordance is tracked as a follow-up — we don't have a lastSeen
/// timestamp on `Accessory` yet.
private struct SonosRoomPickerSheet: View {
    let anchor: Accessory
    let currentMembers: [Accessory]
    let candidates: [Accessory]
    let onApply: (_ additions: [Accessory], _ removals: [Accessory]) async -> Void
    /// Triggered by the `NoSpeakersEmptyState`'s "Scan Again" CTA.
    /// The sheet has no registry access, so the parent owns the
    /// actual discovery kick and passes a closure we can fire.
    let onScanAgain: () async -> Void

    @Environment(\.dismiss) private var dismiss

    /// Toggle state, keyed by AccessoryID. A row is "on" if the
    /// speaker should end up in the anchor's group after apply.
    @State private var selected: Set<AccessoryID> = []
    /// Snapshot of `selected` at mount time. Used by the CTA to
    /// compute the diff — anything `selected ∖ initial` becomes an
    /// addition, anything `initial ∖ selected` becomes a removal.
    @State private var initialSelection: Set<AccessoryID> = []
    @State private var isApplying = false

    /// All speakers presented in the list, in display order:
    ///   1. anchor (always first, marked "This speaker")
    ///   2. current group members (alphabetical — parent sorts)
    ///   3. candidates (alphabetical — parent sorts)
    /// Deduped by AccessoryID on the way in so the anchor never
    /// appears twice even if the parent view's filter logic drifts.
    private var allSpeakers: [Accessory] {
        var seen: Set<AccessoryID> = [anchor.id]
        var result: [Accessory] = [anchor]
        for member in currentMembers where seen.insert(member.id).inserted {
            result.append(member)
        }
        for candidate in candidates where seen.insert(candidate.id).inserted {
            result.append(candidate)
        }
        return result
    }

    /// Count of speakers selected — drives the "Play on N Rooms"
    /// CTA label. We include the anchor in the count so "Play on
    /// 1 Rooms" means "just this speaker" which matches the Pencil
    /// copy. Grammar: "Play on 1 Room" singular, else plural.
    private var selectedCount: Int { selected.count }

    /// Additions = selected ∖ initial, restricted to non-anchors the
    /// caller's `applyRoomPickerDiff` expects as "joiners". If the
    /// anchor was off and is now on, that's handled implicitly by
    /// the additions' join-to-anchor calls (anchor will be the
    /// coordinator).
    private var additions: [Accessory] {
        allSpeakers.filter { speaker in
            selected.contains(speaker.id) &&
                !initialSelection.contains(speaker.id) &&
                speaker.id != anchor.id
        }
    }

    /// Removals = initial ∖ selected. Includes the anchor if the
    /// user explicitly toggled it off (which means "leave the group,
    /// the other members keep playing among themselves").
    private var removals: [Accessory] {
        allSpeakers.filter { speaker in
            initialSelection.contains(speaker.id) &&
                !selected.contains(speaker.id)
        }
    }

    /// CTA is enabled only when there's a pending change — matches
    /// the Pencil design where the button is greyed out until the
    /// user flips at least one toggle.
    private var hasChanges: Bool {
        !additions.isEmpty || !removals.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.color.pageBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            if anchor.nowPlaying != nil || anchor.playbackState == .playing {
                                nowPlayingCard
                            }
                            speakerList
                        }
                        .padding(.horizontal, Theme.space.screenHorizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 100) // Room for the sticky CTA
                    }

                    // Sticky CTA at the bottom. Lives outside the
                    // ScrollView so it doesn't scroll with the list
                    // and always stays reachable with a thumb.
                    VStack(spacing: 0) {
                        Divider().overlay(Theme.color.divider)
                        Button {
                            Task {
                                isApplying = true
                                await onApply(additions, removals)
                                isApplying = false
                                dismiss()
                            }
                        } label: {
                            Text(ctaLabel)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.color.primary)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasChanges || isApplying || selectedCount == 0)
                        .opacity((hasChanges && !isApplying && selectedCount > 0) ? 1 : 0.5)
                        .padding(.horizontal, Theme.space.screenHorizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .background(Theme.color.pageBackground)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            // Seed: anchor + all current group members are ON.
            // Candidates default OFF. Save the snapshot for diffing.
            var seed: Set<AccessoryID> = [anchor.id]
            for member in currentMembers {
                seed.insert(member.id)
            }
            selected = seed
            initialSelection = seed
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Select Rooms")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.color.title)
                Text("Choose where to play music")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.color.iconChipFill)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.color.iconChipGlyph)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var nowPlayingCard: some View {
        let np = anchor.nowPlaying
        let title = np?.title ?? "Nothing Playing"
        let artist = np?.artist ?? "—"
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.color.iconChipFill)
                    .frame(width: 52, height: 52)
                if let art = np?.coverArtURL {
                    AsyncImage(url: art) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Image(systemName: "music.note")
                                .foregroundStyle(Theme.color.iconChipGlyph)
                        }
                    }
                } else {
                    Image(systemName: "music.note")
                        .foregroundStyle(Theme.color.iconChipGlyph)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text(artist)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.subtitle)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "pause.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.color.iconChipFill))
        }
        .padding(12)
        .hcCard(padding: 0)
    }

    @ViewBuilder
    private var speakerList: some View {
        if allSpeakers.count <= 1 {
            // Full Pencil `375nI` empty state. Scan Again kicks the
            // provider discovery sweep; the manual setup link is
            // wired to nil for now — we'll plumb it when the
            // `Oa5ev Device Pairing` flow lands.
            NoSpeakersEmptyState(
                onScanAgain: {
                    Task { await onScanAgain() }
                },
                onManualSetup: nil
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(allSpeakers.enumerated()), id: \.element.id) { idx, speaker in
                    speakerRow(for: speaker)
                    if idx < allSpeakers.count - 1 {
                        Divider()
                            .overlay(Theme.color.divider)
                            .padding(.leading, 48)
                    }
                }
            }
            .hcCard(padding: 0)
        }
    }

    private func speakerRow(for speaker: Accessory) -> some View {
        let isOn = selected.contains(speaker.id)
        let isOffline = !speaker.isReachable
        let isAnchor = speaker.id == anchor.id

        // Subtitle logic: anchor says "This speaker", offline
        // rows get the red warning, otherwise fall back to the
        // speaker's model/category hint.
        let subtitle: String = {
            if isOffline { return "Speaker offline" }
            if isAnchor { return "This speaker" }
            return speaker.manufacturerName ?? "Sonos"
        }()

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn ? Theme.color.primary.opacity(0.15) : Theme.color.iconChipFill)
                    .frame(width: 36, height: 36)
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.color.primary : Theme.color.iconChipGlyph)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(speaker.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(isOffline ? Color.red : Theme.color.subtitle)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { selected.contains(speaker.id) },
                set: { newValue in
                    if newValue {
                        selected.insert(speaker.id)
                    } else {
                        selected.remove(speaker.id)
                    }
                }
            ))
            .labelsHidden()
            .tint(Theme.color.primary)
            .disabled(isOffline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(isOffline ? 0.55 : 1)
    }

    private var ctaLabel: String {
        if selectedCount == 0 { return "Select a room" }
        if selectedCount == 1 { return "Play on 1 Room" }
        return "Play on \(selectedCount) Rooms"
    }
}

// MARK: - Accessory name-hint helper

private extension Accessory {
    /// Best-effort subtitle for the room picker. Sonos' unified
    /// `Accessory` doesn't carry a model field yet, so we just
    /// return "Sonos" — good enough for the picker row and
    /// trivially upgradable once `Accessory.model` exists.
    var manufacturerName: String? { "Sonos" }
}

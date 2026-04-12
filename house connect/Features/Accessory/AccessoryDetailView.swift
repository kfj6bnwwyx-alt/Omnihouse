//
//  AccessoryDetailView.swift
//  house connect
//
//  Detail screen for a single accessory. Handles:
//    • Renaming (provider-routed, works for any ecosystem that opts in)
//    • Power toggle
//    • Brightness slider (if the accessory supports it)
//    • Camera preview (if the accessory is a camera)
//

import SwiftUI

struct AccessoryDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String = ""
    @State private var isRenaming = false
    @State private var isReassigning = false
    @State private var isRemoving = false
    @State private var showRemoveConfirmation = false
    @State private var errorMessage: String?

    // Derived: the live accessory out of the registry. If it disappears
    // (pairing removed, etc.) we dismiss.
    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        Form {
            if let accessory {
                nameSection(accessory)

                if accessory.category == .camera {
                    Section("Live view") {
                        CameraPreview(accessoryID: accessory.id)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200)
                    }
                }

                controlsSection(accessory)
                mediaSection(accessory)
                groupedPartsSection(accessory)
                speakerGroupSection(accessory)
                joinGroupSection(accessory)
                roomSection(accessory)
                infoSection(accessory)
                removeSection(accessory)
            } else {
                ContentUnavailableView("Accessory unavailable",
                                       systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(accessory?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draftName = accessory?.name ?? ""
        }
        .alert("Operation failed",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }),
               actions: { Button("OK") { errorMessage = nil } },
               message: { Text(errorMessage ?? "") })
    }

    // MARK: - Sections

    private func nameSection(_ accessory: Accessory) -> some View {
        Section("Name") {
            HStack {
                TextField("Accessory name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { Task { await commitRename(accessory) } }
                if isRenaming {
                    ProgressView()
                } else if draftName != accessory.name && !draftName.isEmpty {
                    Button("Save") { Task { await commitRename(accessory) } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func controlsSection(_ accessory: Accessory) -> some View {
        if accessory.isOn != nil || accessory.brightness != nil {
            Section("Controls") {
                if let isOn = accessory.isOn {
                    Toggle("Power", isOn: Binding(
                        get: { isOn },
                        set: { newValue in
                            Task { await sendCommand(.setPower(newValue), on: accessory) }
                        }
                    ))
                    .disabled(!accessory.isReachable)
                }

                if let brightness = accessory.brightness {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Brightness")
                            Spacer()
                            Text("\(Int(brightness * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { brightness },
                                set: { newValue in
                                    Task {
                                        await sendCommand(.setBrightness(newValue), on: accessory)
                                    }
                                }
                            ),
                            in: 0...1
                        )
                        .disabled(!accessory.isReachable)
                    }
                }
            }
        }
    }

    // MARK: - Media (speakers, TVs — anything that opts into playback/volume)

    @ViewBuilder
    private func mediaSection(_ accessory: Accessory) -> some View {
        if accessory.isMediaPlayer {
            Section("Media") {
                // Now playing metadata, if the provider reported any.
                if let np = accessory.nowPlaying,
                   (np.title != nil || np.artist != nil) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = np.title {
                            Text(title).font(.body)
                        }
                        if let artist = np.artist {
                            Text(artist).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                // Transport controls. All buttons route through the registry
                // so provider-specific behavior (Sonos SOAP, SmartThings REST)
                // stays hidden behind one command pipeline.
                transportControls(for: accessory)

                // Volume slider — only rendered if the provider currently
                // has a volume reading for this accessory.
                if let volume = accessory.volumePercent {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(volume)%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(volume) },
                                set: { newValue in
                                    Task {
                                        await sendCommand(
                                            .setVolume(Int(newValue.rounded())),
                                            on: accessory
                                        )
                                    }
                                }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        .disabled(!accessory.isReachable)
                    }
                }

                // Mute toggle.
                if let muted = accessory.isMuted {
                    Toggle("Mute", isOn: Binding(
                        get: { muted },
                        set: { newValue in
                            Task { await sendCommand(.setMute(newValue), on: accessory) }
                        }
                    ))
                    .disabled(!accessory.isReachable)
                }
            }
        }
    }

    /// Play / Pause / Previous / Next row. Uses SF Symbols so the layout
    /// stays symmetric regardless of the accessory's current transport state.
    @ViewBuilder
    private func transportControls(for accessory: Accessory) -> some View {
        HStack(spacing: 16) {
            Spacer()

            Button {
                Task { await sendCommand(.previous, on: accessory) }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(!accessory.isReachable)
            .accessibilityLabel("Previous track")

            Button {
                let isPlaying = accessory.playbackState == .playing
                Task { await sendCommand(isPlaying ? .pause : .play, on: accessory) }
            } label: {
                Image(systemName: accessory.playbackState == .playing
                      ? "pause.circle.fill"
                      : "play.circle.fill")
                    .font(.largeTitle)
            }
            .buttonStyle(.borderless)
            .disabled(!accessory.isReachable)
            .accessibilityLabel(accessory.playbackState == .playing ? "Pause" : "Play")

            Button {
                Task { await sendCommand(.next, on: accessory) }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(!accessory.isReachable)
            .accessibilityLabel("Next track")

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func infoSection(_ accessory: Accessory) -> some View {
        Section("Info") {
            LabeledContent("Type", value: accessory.category.rawValue.capitalized)
            LabeledContent("Provider", value: accessory.id.provider.displayLabel)
            LabeledContent("Reachable", value: accessory.isReachable ? "Yes" : "No")
        }
    }

    /// "Parts" — lists the bonded structural components of a single
    /// logical device (home theater bar + sub + rears, stereo pair).
    /// Only shown when the provider populated `groupedParts`, so
    /// ordinary single-speaker tiles don't grow an empty section.
    @ViewBuilder
    private func groupedPartsSection(_ accessory: Accessory) -> some View {
        if let parts = accessory.groupedParts, !parts.isEmpty {
            Section {
                ForEach(Array(parts.enumerated()), id: \.offset) { pair in
                    HStack {
                        Image(systemName: pair.offset == 0
                              ? "hifispeaker.2.fill"
                              : "hifispeaker.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(pair.element)
                        Spacer()
                        if pair.offset == 0 {
                            Text("Main")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Parts")
            } footer: {
                Text("This device is a bonded set — volume and playback control all speakers together.")
            }
        }
    }

    /// "Playing together" — surfaces casual zone group membership AND
    /// exposes the Leave button so the user can tear this room out of
    /// its group without bouncing to the Sonos app. The listing of
    /// other rooms is still read-only here; creating a NEW grouping
    /// lives in `joinGroupSection` below.
    @ViewBuilder
    private func speakerGroupSection(_ accessory: Accessory) -> some View {
        if let group = accessory.speakerGroup, !group.otherMemberNames.isEmpty {
            Section {
                ForEach(group.otherMemberNames, id: \.self) { name in
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(name)
                        Spacer()
                    }
                }
                HStack {
                    Image(systemName: group.isCoordinator
                          ? "crown.fill"
                          : "person.2.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(group.isCoordinator
                         ? "This room is leading playback"
                         : "Playback led by another room")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Leave button — tears this room out of the group.
                // We route through the same `sendCommand` plumbing as
                // play/pause so error surfacing and optimistic refresh
                // are free. The provider handles the topology refetch
                // so the section disappears a beat later once the
                // `speakerGroup` field clears on the Accessory.
                Button(role: .destructive) {
                    Task { await sendCommand(.leaveSpeakerGroup, on: accessory) }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .frame(width: 22)
                        Text("Leave group")
                        Spacer()
                    }
                }
                .disabled(!accessory.isReachable)
            } header: {
                Text("Playing together")
            } footer: {
                Text(group.isCoordinator
                     ? "This room is the coordinator. Leaving the group will promote another room to lead playback."
                     : "Leaving will make this room play alone; the other rooms will keep playing together.")
            }
        }
    }

    /// "Group with…" — the ORIGIN of new speaker groupings. Always
    /// visible on every Sonos media accessory regardless of current
    /// group state, because the user might want to:
    ///   · Pair a standalone room with another room (create a group)
    ///   · Pull a third room into an existing group they're in
    ///   · Swap this room from one group to another
    ///
    /// Shows every OTHER Sonos media accessory. Rooms currently in
    /// the same group as `accessory` are excluded — they'd be a no-op
    /// (you can't "join" a group you're already in). Rooms in a
    /// different group show a caption revealing WHICH group, so
    /// "joining Kitchen" makes sense when Kitchen is already leading
    /// Office too.
    @ViewBuilder
    private func joinGroupSection(_ accessory: Accessory) -> some View {
        // Top-level `let`s in a @ViewBuilder are supported (SE-0380);
        // `let` inside a nested `if` inside a ViewBuilder is legal but
        // fragile in practice — some permutations silently evaporate
        // the whole branch. Pulling both to the top keeps the body
        // purely `if` / view expressions so SwiftUI can reliably
        // render the section.
        //
        // Eligibility uses `category == .speaker` instead of
        // `isMediaPlayer`, because `isMediaPlayer` requires the first
        // status refresh to have landed (it checks for a `volume` or
        // `playback` capability). Sonos accessories are always
        // constructed with `.speaker` at rebuild time, which means
        // the section appears immediately on first render rather than
        // blinking in a beat later after the SOAP sweep completes.
        let isEligible = accessory.id.provider == .sonos && accessory.category == .speaker
        let candidates = isEligible ? joinCandidates(for: accessory) : []

        if isEligible {
            Section {
                if candidates.isEmpty {
                    // Visible empty-state instead of a vanished section
                    // so the user can tell the feature exists even when
                    // there's nothing to offer right now.
                    Text("No other Sonos rooms to join right now.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { candidate in
                        Button {
                            Task {
                                await sendCommand(
                                    .joinSpeakerGroup(target: candidate.id),
                                    on: accessory
                                )
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .foregroundStyle(.primary)
                                    // Reveal the target's existing
                                    // group membership so the user
                                    // knows joining Kitchen may also
                                    // drag Office into the session.
                                    if let theirGroup = candidate.speakerGroup,
                                       !theirGroup.otherMemberNames.isEmpty {
                                        Text("Already with \(theirGroup.otherMemberNames.joined(separator: ", "))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .disabled(!accessory.isReachable)
                    }
                }
            } header: {
                Text("Group with…")
            } footer: {
                Text("Tap a room to make this speaker play along with it. Joining an existing group will pull any other rooms in that group along for the ride.")
            }
        }
    }

    /// Builds the ordered list of Sonos accessories this speaker could
    /// join right now. Pulled out of `joinGroupSection` because the
    /// inlined chained filter/sort was tripping Swift's @ViewBuilder
    /// type inference into "the compiler is unable to type-check this
    /// expression in reasonable time" — a plain func body typechecks
    /// in microseconds where the inlined closure chain was blowing up
    /// the whole detail view.
    ///
    /// Filters:
    ///   1. Drop self — "group with myself" is a no-op.
    ///   2. Sonos-only — HomeKit / SmartThings / Nest can't group.
    ///   3. Must be a speaker by category — we gate on `.speaker`
    ///      rather than `isMediaPlayer` because the latter depends
    ///      on a status-refresh cycle having already populated
    ///      volume/playback capabilities, creating a first-render
    ///      race where the list would show empty for a beat.
    ///   4. Drop anything already in MY group — tapping a room already
    ///      playing with us would be another no-op, and the Leave
    ///      button is the right control for that case.
    /// Sort: alphabetical by name so the list is stable across refreshes.
    private func joinCandidates(for accessory: Accessory) -> [Accessory] {
        let myGroupID: String? = accessory.speakerGroup?.groupID
        var result: [Accessory] = []
        for candidate in registry.allAccessories {
            if candidate.id == accessory.id { continue }
            if candidate.id.provider != .sonos { continue }
            if candidate.category != .speaker { continue }
            if let myGroupID, candidate.speakerGroup?.groupID == myGroupID {
                continue
            }
            result.append(candidate)
        }
        result.sort { a, b in
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return result
    }

    /// Room picker constrained to rooms in the SAME provider as this
    /// accessory. Cross-provider assignment requires the capability-union
    /// linking work in Phase 3c and isn't offered here.
    @ViewBuilder
    private func roomSection(_ accessory: Accessory) -> some View {
        let eligibleRooms = registry.allRooms
            .filter { $0.provider == accessory.id.provider }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        Section {
            Picker(selection: Binding(
                get: { accessory.roomID },
                set: { newRoomID in
                    Task { await reassign(accessory, toRoomID: newRoomID) }
                }
            )) {
                Text("No room")
                    .tag(Optional<String>.none)
                ForEach(eligibleRooms) { room in
                    Text(room.name).tag(Optional(room.id))
                }
            } label: {
                HStack {
                    Label("Room", systemImage: "square.grid.2x2")
                    if isReassigning {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isReassigning || eligibleRooms.isEmpty)

            if eligibleRooms.isEmpty {
                Text("No rooms in \(accessory.id.provider.displayLabel) yet. Create one from the Rooms button on the dashboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Assignment")
        }
    }

    // MARK: - Remove device

    @ViewBuilder
    private func removeSection(_ accessory: Accessory) -> some View {
        Section {
            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                HStack {
                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Remove Device")
                    Spacer()
                    Image(systemName: "trash")
                }
            }
            .disabled(isRemoving)
            .confirmationDialog(
                "Remove \(accessory.name)?",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    Task { await performRemove(accessory) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will unpair the device from \(accessory.id.provider.displayLabel). You can re-add it later from the Add tab.")
            }
        } footer: {
            Text("Removes this accessory from \(accessory.id.provider.displayLabel).")
        }
    }

    // MARK: - Actions

    private func performRemove(_ accessory: Accessory) async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await registry.removeAccessory(accessory.id)
            dismiss()
        } catch {
            errorMessage = "Could not remove \(accessory.name): \(Self.describe(error))"
        }
    }

    private func commitRename(_ accessory: Accessory) async {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != accessory.name else { return }
        isRenaming = true
        defer { isRenaming = false }
        do {
            try await registry.rename(accessoryID: accessory.id, to: trimmed)
        } catch {
            errorMessage = "Could not rename: \(Self.describe(error))"
            draftName = accessory.name
        }
    }

    private func sendCommand(_ command: AccessoryCommand, on accessory: Accessory) async {
        do {
            try await registry.execute(command, on: accessory.id)
        } catch {
            errorMessage = "\(accessory.name): \(Self.describe(error))"
        }
    }

    private func reassign(_ accessory: Accessory, toRoomID newRoomID: String?) async {
        // No-op when the user re-picks the already-selected room.
        guard newRoomID != accessory.roomID else { return }
        isReassigning = true
        defer { isReassigning = false }
        do {
            try await registry.assignAccessory(accessory.id, toRoomID: newRoomID)
        } catch {
            errorMessage = "Could not move \(accessory.name): \(Self.describe(error))"
        }
    }

    /// Unwraps any error into the human-readable message that
    /// `LocalizedError` provides, falling back to
    /// `localizedDescription` for framework errors. We had been
    /// using raw `"\(error)"` interpolation, which renders the
    /// synthesized case name — e.g. `underlying("SmartThings
    /// error 429...")` — right into the alert. That's developer
    /// output leaking into user space. This helper is the single
    /// choke-point so the three call sites above don't drift.
    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

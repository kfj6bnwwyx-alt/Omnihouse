//
//  T3RoomsSettingsView.swift
//  house connect
//
//  Settings → Rooms. The rooms management screen, distinct from the
//  Rooms tab's browse/control grid. Lists every room grouped by the
//  provider that owns it, so cross-provider duplicates (e.g. "Family
//  Room" from HomeKit and "family_room" from Home Assistant) are
//  visible as separate entries and the source of each is obvious.
//
//  Previously Settings → Rooms pushed `T3RoomsTabView` (the tab root)
//  onto the shared NavigationStack, producing a duplicate screen with
//  no T3 back header. This view replaces that destination.
//
//  Future home for cross-provider room merging: each row already has
//  the provider label + name pair that a `RoomLinkStore` will need.
//

import SwiftUI

struct T3RoomsSettingsView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(RoomLinkStore.self) private var roomLinkStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreate = false
    @State private var showingLinkPicker = false
    @State private var unlinkCandidate: ManualRoomLink?
    @State private var confirmClearLinks = false

    /// Rooms grouped by the provider that owns them. Preserves the
    /// registered provider order so the list is stable across launches.
    private var groupedRooms: [(ProviderID, [Room])] {
        var groups: [ProviderID: [Room]] = [:]
        for room in registry.allRooms {
            groups[room.provider, default: []].append(room)
        }
        // Sort rooms inside each group by name; outer order follows
        // the provider registration order (HomeKit → SmartThings →
        // Sonos → Nest → HA, per house_connectApp.swift).
        let providerOrder = registry.providers.map(\.id)
        return providerOrder.compactMap { pid in
            guard let rooms = groups[pid], !rooms.isEmpty else { return nil }
            return (pid, rooms.sorted { $0.name < $1.name })
        }
    }

    private var totalRoomCount: Int {
        registry.allRooms.count
    }

    private var crossProviderDuplicates: [String] {
        var byName: [String: Set<ProviderID>] = [:]
        for room in registry.allRooms {
            byName[room.name.lowercased(), default: []].insert(room.provider)
        }
        return byName
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
    }

    /// Duplicates the user hasn't resolved with a link yet. Keeps the
    /// banner actionable — if you've already linked two "Family Room"
    /// entries across providers, that's not a duplicate anymore.
    private var unlinkedDuplicates: [String] {
        let linked = roomLinkStore.linkedKeys()
        var byName: [String: Set<ProviderID>] = [:]
        for room in registry.allRooms {
            let key = RoomKey(room)
            if linked.contains(key) { continue }
            byName[room.name.lowercased(), default: []].insert(room.provider)
        }
        return byName
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                THeader(backLabel: "Settings", onBack: { dismiss() })
                TTitle(
                    title: "Rooms.",
                    subtitle: "\(totalRoomCount) rooms across \(groupedRooms.count) \(groupedRooms.count == 1 ? "provider" : "providers")"
                )

                // Duplicate warning — flags rooms whose name appears
                // under more than one provider and that aren't
                // already linked. Linked duplicates are expected and
                // desired, so suppress the warning for them.
                if !unlinkedDuplicates.isEmpty {
                    duplicatesBanner
                }

                // Existing links
                if !roomLinkStore.links.isEmpty {
                    TSectionHead(title: "Linked rooms",
                                 count: String(format: "%02d", roomLinkStore.links.count))
                    ForEach(Array(roomLinkStore.links.enumerated()), id: \.element.id) { i, link in
                        linkRow(link, isLast: i == roomLinkStore.links.count - 1)
                    }
                    Button {
                        confirmClearLinks = true
                    } label: {
                        Text("Clear all links")
                            .font(T3.inter(13, weight: .medium))
                            .foregroundStyle(T3.danger)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                // One section per provider
                ForEach(Array(groupedRooms.enumerated()), id: \.element.0) { _, group in
                    let providerID = group.0
                    let rooms = group.1

                    TSectionHead(
                        title: providerID.displayLabel,
                        count: String(format: "%02d", rooms.count)
                    )

                    ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                        roomRow(room, isLast: i == rooms.count - 1)
                    }
                }

                // Create room — HomeKit is the only provider in the
                // current lineup that exposes a user-creatable room
                // API; other providers (HA areas, SmartThings rooms)
                // are managed from their native apps. The sheet itself
                // shows a provider picker + friendly error if none
                // support creation.
                TSectionHead(title: "Actions")

                actionRow(icon: "link.badge.plus", title: "Link rooms",
                          sub: "Merge same room across providers",
                          action: { showingLinkPicker = true })

                actionRow(icon: "plus", title: "Create room",
                          sub: "HomeKit · Home Assistant",
                          action: { showingCreate = true })

                // Explainer
                Text("Rooms come from each connected provider. Renaming or deleting a room must be done in that provider's native app — the changes flow back here on the next refresh.")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 16)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .refreshable {
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in await provider.refresh() }
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            T3CreateRoomSheet()
                .environment(registry)
        }
        .sheet(isPresented: $showingLinkPicker) {
            T3LinkRoomPickerSheet()
                .environment(registry)
                .environment(roomLinkStore)
        }
        .confirmationDialog("Unlink rooms?", isPresented: Binding(
            get: { unlinkCandidate != nil },
            set: { if !$0 { unlinkCandidate = nil } }
        ), titleVisibility: .visible) {
            Button("Unlink", role: .destructive) {
                if let c = unlinkCandidate { roomLinkStore.removeLink(id: c.id) }
                unlinkCandidate = nil
            }
            Button("Cancel", role: .cancel) { unlinkCandidate = nil }
        } message: {
            if let c = unlinkCandidate {
                Text("\"\(roomName(c.primary))\" and \"\(roomName(c.secondary))\" will show as separate rooms again.")
            }
        }
        .confirmationDialog("Clear all room links?", isPresented: $confirmClearLinks, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { roomLinkStore.removeAllLinks() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes every linked-rooms pair. You can relink them from this screen.")
        }
    }

    // MARK: - Rows

    /// Each room row is a NavigationLink to the same detail view the
    /// Rooms tab uses, so taps from Settings behave identically to
    /// taps from the browse grid.
    private func roomRow(_ room: Room, isLast: Bool) -> some View {
        let deviceCount = registry.allAccessories.filter { $0.roomID == room.id && $0.id.provider == room.provider }.count
        let activeCount = registry.allAccessories.filter { $0.roomID == room.id && $0.id.provider == room.provider && $0.isOn == true }.count

        return NavigationLink(value: room) {
            HStack(spacing: 14) {
                T3IconImage(systemName: roomIcon(room.name))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if activeCount > 0 { TDot(size: 5) }
                        Text("\(activeCount)/\(deviceCount) on")
                            .font(T3.mono(10))
                            .foregroundStyle(T3.sub)
                            .tracking(0.6)
                    }
                }

                Spacer()

                T3IconImage(systemName: "chevron.right")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.t3Row)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private var duplicatesBanner: some View {
        Button {
            showingLinkPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(T3.accent)
                        .frame(width: 8, height: 8)
                    Text("Unlinked duplicates")
                        .font(T3.inter(13, weight: .medium))
                        .foregroundStyle(T3.ink)
                    Spacer()
                    Text("TAP TO LINK")
                        .font(T3.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(T3.accent)
                }
                Text("\(unlinkedDuplicates.count) \(unlinkedDuplicates.count == 1 ? "room appears" : "rooms appear") under more than one provider: \(unlinkedDuplicates.prefix(3).joined(separator: ", "))\(unlinkedDuplicates.count > 3 ? ", …" : ""). Link them so they show as one tile.")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Helpers

    private func actionRow(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                T3IconImage(systemName: icon)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    Text(sub)
                        .font(T3.inter(11, weight: .regular))
                        .foregroundStyle(T3.sub)
                }
                Spacer()
                T3IconImage(systemName: "chevron.right")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    private func linkRow(_ link: ManualRoomLink, isLast: Bool) -> some View {
        let primary = roomName(link.primary)
        let secondary = roomName(link.secondary)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TDot(size: 5, color: T3.accent)
                    Text(primary)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    TDot(size: 5, color: T3.sub)
                    Text(secondary)
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(link.primary.provider.displayLabel.uppercased())
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                    Text("→")
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                    Text(link.secondary.provider.displayLabel.uppercased())
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                }
            }
            Spacer()
            Button {
                unlinkCandidate = link
            } label: {
                T3IconImage(systemName: "xmark")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func roomName(_ key: RoomKey) -> String {
        registry.allRooms
            .first { $0.id == key.roomID && $0.provider == key.provider }?
            .name ?? key.roomID
    }

    private func roomIcon(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("living") || lower.contains("family") || lower.contains("den") { return "sofa.fill" }
        if lower.contains("kitchen") { return "fork.knife" }
        if lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("bath") { return "shower.fill" }
        if lower.contains("entry") || lower.contains("door") { return "door.left.hand.open" }
        if lower.contains("office") || lower.contains("study") { return "desktopcomputer" }
        return "square.grid.2x2.fill"
    }
}

// MARK: - Link rooms picker

/// Two-step picker mirroring T3LinkDevicePickerSheet. Pick a primary
/// room in step 1, a secondary in step 2, tap Link to persist.
/// Already-linked rooms are filtered out of both steps so the user
/// can't double-link a pair.
struct T3LinkRoomPickerSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(RoomLinkStore.self) private var roomLinkStore
    @Environment(\.dismiss) private var dismiss

    @State private var primary: RoomKey?
    @State private var secondary: RoomKey?
    @State private var step: Int = 1

    private var eligibleRooms: [Room] {
        let linked = roomLinkStore.linkedKeys()
        let all = registry.allRooms
            .filter { !linked.contains(RoomKey($0)) }
            .sorted { $0.name < $1.name }
        guard step == 2, let primary else { return all }
        return all.filter { RoomKey($0) != primary }
    }

    private var primaryName: String {
        guard let primary else { return "—" }
        return registry.allRooms
            .first { $0.id == primary.roomID && $0.provider == primary.provider }?
            .name ?? primary.roomID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TTitle(
                        title: step == 1 ? "Pick first." : "Pick second.",
                        subtitle: step == 1
                            ? "The primary room (name you want to keep)"
                            : "The matching room on another provider"
                    )
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)

                    if step == 2 {
                        HStack(spacing: 8) {
                            TDot(size: 6)
                            Text("Primary: \(primaryName)")
                                .font(T3.inter(13, weight: .medium))
                                .foregroundStyle(T3.ink)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 10)
                        TRule()
                    }

                    ForEach(Array(eligibleRooms.enumerated()), id: \.element.id) { i, room in
                        let key = RoomKey(room)
                        let isSelected = (step == 1 ? primary : secondary) == key
                        Button {
                            if step == 1 {
                                primary = key
                                secondary = nil
                                step = 2
                            } else {
                                secondary = key
                            }
                        } label: {
                            HStack(spacing: 14) {
                                T3IconImage(systemName: "square.grid.2x2")
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(T3.ink)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                        .font(T3.inter(15, weight: .medium))
                                        .foregroundStyle(T3.ink)
                                    Text(room.provider.displayLabel.uppercased())
                                        .font(T3.mono(9))
                                        .foregroundStyle(T3.sub)
                                        .tracking(1)
                                }
                                Spacer()
                                if isSelected {
                                    T3IconImage(systemName: "checkmark")
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(T3.accent)
                                }
                            }
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 13)
                            .overlay(alignment: .top) { TRule() }
                            .overlay(alignment: .bottom) {
                                if i == eligibleRooms.count - 1 { TRule() }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if eligibleRooms.isEmpty {
                        Text(step == 1
                             ? "No unlinked rooms available."
                             : "No other rooms to link. Pick a different primary.")
                            .font(T3.inter(13, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 24)
                    }

                    Spacer(minLength: 120)
                }
            }
            .background(T3.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == 2 ? "Back" : "Cancel") {
                        if step == 2 {
                            step = 1
                            primary = nil
                            secondary = nil
                        } else {
                            dismiss()
                        }
                    }
                }
                if step == 2, let p = primary, let s = secondary, p != s {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Link") {
                            roomLinkStore.addLink(primary: p, secondary: s)
                            dismiss()
                        }
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.accent)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .modifier(T3SheetChromeModifier())
    }
}

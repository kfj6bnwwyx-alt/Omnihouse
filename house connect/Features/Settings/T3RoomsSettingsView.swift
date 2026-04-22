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
    @State private var showingCreate = false

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: "Rooms.",
                    subtitle: "\(totalRoomCount) rooms across \(groupedRooms.count) \(groupedRooms.count == 1 ? "provider" : "providers")"
                )
                .t3ScreenTopPad()

                // Duplicate warning — flags rooms whose name appears
                // under more than one provider. Cross-provider room
                // merging isn't built yet; this at least makes the
                // split visible so the user isn't confused by two
                // "Family Room" tiles on the Home dashboard.
                if !crossProviderDuplicates.isEmpty {
                    duplicatesBanner
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

                Button {
                    showingCreate = true
                } label: {
                    HStack(spacing: 14) {
                        T3IconImage(systemName: "plus")
                            .frame(width: 18, height: 18)
                            .foregroundStyle(T3.ink)
                        Text("Create room")
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                        Spacer()
                        T3IconImage(systemName: "chevron.right")
                            .frame(width: 12, height: 12)
                            .foregroundStyle(T3.sub)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }

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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(T3.accent)
                    .frame(width: 8, height: 8)
                Text("Cross-provider duplicates")
                    .font(T3.inter(13, weight: .medium))
                    .foregroundStyle(T3.ink)
            }
            Text("\(crossProviderDuplicates.count) \(crossProviderDuplicates.count == 1 ? "room appears" : "rooms appear") under more than one provider: \(crossProviderDuplicates.prefix(3).joined(separator: ", "))\(crossProviderDuplicates.count > 3 ? ", …" : ""). They show as separate tiles until cross-provider room merging ships.")
                .font(T3.inter(12, weight: .regular))
                .foregroundStyle(T3.sub)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { TRule() }
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

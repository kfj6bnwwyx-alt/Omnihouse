//
//  AllRoomsView.swift
//  house connect
//
//  The ROOMS tab. Matches the Pencil design (node iVVkt):
//    - Large "All Rooms" title + purple "+" button
//    - Search bar
//    - 2-column grid of room cards with lavender icon chip + name + device count
//
//  This replaces the old sheet-presented `RoomsListView` (which used a
//  sectioned List). The old file is kept around so its existing detail
//  navigation still compiles until we retire it.
//
//  Create-room / rename / delete flow still lives in CreateRoomSheet and
//  RoomDetailView — this view is read-only drill-through plus search.
//

import SwiftUI

struct AllRoomsView: View {
    @Environment(ProviderRegistry.self) private var registry

    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var showingCreate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                searchField
                content
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .refreshable {
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in
                        await provider.refresh()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(roomID: room.id, providerID: room.provider)
        }
        .sheet(isPresented: $showingCreate) {
            CreateRoomSheet()
                .environment(registry)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.chip,
                                         style: .continuous)
                            .fill(Theme.color.cardFill)
                            .shadow(color: .black.opacity(0.05),
                                    radius: 6, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Back")

            Text("All Rooms")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                showingCreate = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.color.primary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(registry.allHomes.isEmpty)
            .accessibilityLabel("Create room")
            .accessibilityHint("Opens a sheet to create a new room")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.color.muted)
                .accessibilityHidden(true)
            TextField("Search rooms…", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.color.title)
                .accessibilityLabel("Search rooms")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.color.muted)
                }
                .accessibilityLabel("Clear search")
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
        let rooms = filteredRooms
        if rooms.isEmpty {
            if query.isEmpty {
                // First-run / no-providers state — show the full Pencil
                // `ApNW6` empty state with the big icon chip and "Add a
                // Room" CTA that opens the existing CreateRoomSheet.
                NoRoomsEmptyState(onAddRoom: { showingCreate = true })
            } else {
                // Search-miss state — compact, in-context card. Not
                // worth the full hero treatment because the user
                // clearly has rooms, just not matching the query.
                VStack(alignment: .leading, spacing: 8) {
                    Text("No matches")
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text("Try a different search term.")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .hcCard()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No matches. Try a different search term.")
            }
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12),
                          GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(rooms) { room in
                    NavigationLink(value: room) {
                        RoomTile(
                            room: room,
                            deviceCount: deviceCount(in: room)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(room.name), \(deviceCount(in: room)) devices")
                    .accessibilityHint("Opens room details")
                }
            }
        }
    }

    // MARK: - Data helpers

    /// Searchable, sorted list of rooms unified across every provider.
    /// Rooms with the same (case-insensitive, whitespace-trimmed) name
    /// collapse into a single tile — e.g. HomeKit's "Den" and Sonos'
    /// "Den" render as one entry — so the user sees rooms the way they
    /// think about them physically instead of per-provider silos.
    ///
    /// The tile that wins the merge is the first one by provider
    /// iteration order (HomeKit → SmartThings → Sonos → Nest). The
    /// NavigationLink value is still a single `Room`, so
    /// RoomDetailView gets an anchor room to read name/homeID off of;
    /// it re-derives sibling rooms and merged accessory lists on its
    /// own. This keeps navigation typing simple — no new
    /// "virtual room" model — while still producing the unified view.
    private var filteredRooms: [Room] {
        let all = registry.allRooms
        var seen = Set<String>()
        var deduped: [Room] = []
        for room in all {
            let key = room.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !key.isEmpty else { continue }
            if seen.insert(key).inserted {
                deduped.append(room)
            }
        }
        let sorted = deduped.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return sorted }
        return sorted.filter {
            $0.name.range(of: query, options: .caseInsensitive) != nil
        }
    }

    /// Counts every accessory whose room name matches this tile's
    /// name, across every provider — not just the one that won the
    /// dedupe. That's why a merged "Den" tile reads "5 devices"
    /// when it's really 4 HomeKit lights + 1 Sonos speaker.
    private func deviceCount(in room: Room) -> Int {
        let matchingRoomIDs = siblingRoomIDs(matching: room)
        return registry.allAccessories.filter {
            guard let rid = $0.roomID else { return false }
            return matchingRoomIDs.contains(rid)
        }.count
    }

    /// All room IDs (across every provider) whose name matches
    /// `anchor.name` — the set that makes up a "virtual room".
    /// Used by both the tile device count and RoomDetailView, so
    /// the two stay consistent.
    private func siblingRoomIDs(matching anchor: Room) -> Set<String> {
        let key = anchor.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return Set(
            registry.allRooms
                .filter {
                    $0.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased() == key
                }
                .map(\.id)
        )
    }
}

//
//  HomeDashboardView.swift
//  house connect
//
//  The HOME tab. Matches the Pencil design (node A1WUK):
//    - Greeting header + home name + profile avatar
//    - Weather card (placeholder: no weather provider wired yet)
//    - Quick Scenes horizontal tile row — taps run the scene via SceneRunner
//    - My Rooms 2-column card grid — taps drill into RoomDetailView
//
//  This replaces the old flat-accessory-list DashboardView. Nothing in the
//  old file survives — it's a rewrite, not a refactor.
//
//  Data sources:
//    - `registry.allHomes`        → header subtitle ("Maple Street Home")
//    - `registry.allRooms`        → room grid
//    - `registry.allAccessories`  → per-room device count badge
//    - `sceneStore.scenes`        → scene tile row
//
//  Notes:
//  ------
//  - The greeting is time-based (Morning/Afternoon/Evening/Night). We
//    don't know the user's name yet — the Pencil mock says "Good Morning,
//    Alex" but we don't have a user profile model. Falling back to
//    "Good Morning" for now; plug a profile model into Phase 2c polish.
//  - Weather card is a static placeholder. Real data needs a backend or
//    an iOS WeatherKit wiring — out of scope for Phase 2c.
//  - Scene-run errors are surfaced via an alert, not swallowed.
//

import SwiftUI

struct HomeDashboardView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(SceneStore.self) private var sceneStore
    @Environment(AppEventStore.self) private var eventStore
    @Environment(WeatherService.self) private var weather

    @State private var runningSceneID: UUID?
    @State private var toast: Toast?
    @State private var showingCreateRoom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                    .padding(.top, 8)
                weatherCard
                homeStatusRow
                DisconnectedProviderBanners()
                quickScenesSection
                roomsSection
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .refreshable {
            // Refresh all providers + weather in parallel. The weather
            // cache is 15 min, but a manual pull-to-refresh should always
            // force a fresh fetch so the user sees it update.
            weather.fetchIfNeeded()
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in
                        await provider.refresh()
                    }
                }
            }
            // Surface a toast if any provider failed to refresh so the
            // user knows the pull didn't silently fail.
            let errors = registry.providers.compactMap { p in
                (p as? SmartThingsProvider)?.lastError
                    ?? (p as? NestProvider)?.lastError
            }
            if !errors.isEmpty {
                toast = .error("Some providers couldn't refresh")
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(roomID: room.id, providerID: room.provider)
        }
        .navigationDestination(for: HomeDestination.self) { dest in
            switch dest {
            case .notifications: NotificationsCenterView()
            }
        }
        .navigationDestination(for: SettingsDestination.self) { dest in
            switch dest {
            case .providers: ProvidersSettingsView()
            case .rooms: AllRoomsView()
            case .scenes: ScenesListView()
            case .audioZones: AudioZonesMapView()
            case .networkTopology: DeviceNetworkTopologyView()
            case .about: AboutView()
            case .helpFAQ: HelpFAQView()
            case .notifications: NotificationPreferencesView()
            case .appearance: AppearanceView()
            }
        }
        .toast($toast)
        .sheet(isPresented: $showingCreateRoom) {
            CreateRoomSheet()
        }
    }

    // MARK: - Header

    /// Big greeting + home subtitle + circular avatar button.
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(Theme.font.screenTitle)
                    .foregroundStyle(Theme.color.title)
                Text(homeName)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            // Notification bell — pushes the Pencil mCjOM feed.
            // Overlaid unread badge uses a stable topTrailing alignment
            // so the pip doesn't jump when the count flips digits.
            NavigationLink(value: HomeDestination.notifications) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Theme.color.iconChipFill)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Theme.color.title)
                        )
                    if eventStore.unreadCount > 0 {
                        Text(eventStore.unreadCount > 9 ? "9+" : "\(eventStore.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(.horizontal, 3)
                            .background(
                                Capsule().fill(Color(red: 0.93, green: 0.29, blue: 0.27))
                            )
                            .offset(x: 4, y: -4)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(eventStore.unreadCount > 0
                    ? "Notifications, \(eventStore.unreadCount) unread"
                    : "Notifications")
                .accessibilityHint("Double tap to view notifications")
                .accessibilityAddTraits(.isButton)
            }
            .buttonStyle(.plain)
            Circle()
                .fill(Theme.color.primary)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                )
                .accessibilityLabel("Profile")
                .accessibilityAddTraits(.isImage)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    /// Falls back to a generic label if no home is registered (e.g. user
    /// hasn't granted HomeKit permission yet).
    private var homeName: String {
        if let primary = registry.allHomes.first(where: \.isPrimary) {
            return primary.name
        }
        return registry.allHomes.first?.name ?? "No home connected"
    }

    // MARK: - Weather card (live via Open-Meteo)

    /// Real weather from Open-Meteo + CoreLocation. Falls back to a
    /// "Weather unavailable" state if location is denied or the
    /// network is down — never shows a spinner or error state because
    /// the card should always feel like furniture, not a loading
    /// indicator.
    private var weatherCard: some View {
        HStack(spacing: 14) {
            IconChip(systemName: weather.iconName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(weather.headline)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .redacted(reason: weather.isLoading ? .placeholder : [])
                if !weather.suggestion.isEmpty {
                    Text(weather.suggestion)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .redacted(reason: weather.isLoading ? .placeholder : [])
                }
            }
            Spacer()
        }
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weather.headline). \(weather.suggestion)")
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            weather.fetchIfNeeded()
        }
    }

    // MARK: - Home status row

    /// Compact status row showing total devices, how many are active,
    /// and an offline warning when applicable. Sits between the weather
    /// card and Quick Scenes as a lightweight at-a-glance health check.
    /// Only renders when there are any devices at all (empty homes
    /// shouldn't show a "0 devices" pill).
    @ViewBuilder
    private var homeStatusRow: some View {
        let all = registry.allAccessories
        if !all.isEmpty {
            let active = all.filter { $0.isOn == true }.count
            let offline = all.filter { !$0.isReachable }.count

            HStack(spacing: 12) {
                statusChip(
                    icon: "square.grid.2x2.fill",
                    text: "\(all.count) device\(all.count == 1 ? "" : "s")",
                    color: Theme.color.primary
                )
                statusChip(
                    icon: "bolt.fill",
                    text: "\(active) active",
                    color: .green
                )
                if offline > 0 {
                    statusChip(
                        icon: "wifi.slash",
                        text: "\(offline) offline",
                        color: .orange
                    )
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Home status: \(all.count) device\(all.count == 1 ? "" : "s"), \(active) active\(offline > 0 ? ", \(offline) offline" : "")")
        }
    }

    private func statusChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.color.subtitle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.color.cardFill)
                .shadow(color: Color.black.opacity(0.04),
                        radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Quick Scenes

    private var quickScenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Scenes")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sceneStore.scenes) { scene in
                        SceneTile(
                            scene: scene,
                            isRunning: runningSceneID == scene.id,
                            onTap: { run(scene) }
                        )
                    }
                    NavigationLink(value: ScenesDestination.list) {
                        SceneTile.newSceneTile
                    }
                    .buttonStyle(.plain)
                }
                // Slight overflow so the shadow on the leftmost card isn't clipped.
                .padding(.vertical, 4)
            }
        }
        .navigationDestination(for: ScenesDestination.self) { dest in
            switch dest {
            case .list: ScenesListView()
            case .editor(let sceneID): SceneEditorView(sceneID: sceneID)
            }
        }
    }

    // MARK: - Rooms

    /// 2-column grid of room cards. Drills into RoomDetailView on tap.
    /// We show all rooms across all providers flat-sorted by name — the
    /// Pencil design doesn't segment by provider on this screen.
    ///
    /// Rooms with the same (case-insensitive, whitespace-trimmed) name
    /// collapse into a single tile so HomeKit's "Den" and Sonos' "Den"
    /// render as one card. The winner by provider iteration order gets
    /// used as the NavigationLink anchor; RoomDetailView re-derives its
    /// sibling set from there. Keeps this screen in sync with the
    /// Rooms tab (AllRoomsView) which dedupes the same way.
    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Rooms")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)

            let rooms = dedupedRooms

            if rooms.isEmpty {
                // Full Pencil `ApNW6` empty state. The CTA is a no-op
                // here because the Home dashboard doesn't own the
                // Create-Room sheet — that lives in the Rooms tab.
                // Tapping "Add a Room" bounces the user there via a
                // tab-switch environment key (see RootView). If the
                // tab-switch hook isn't wired yet, the button still
                // renders correctly and does nothing — harmless.
                NoRoomsEmptyState(onAddRoom: { showingCreateRoom = true })
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
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func run(_ scene: HCScene) {
        guard runningSceneID == nil else { return }
        runningSceneID = scene.id
        Task {
            let result = await SceneRunner(registry: registry).run(scene)
            runningSceneID = nil
            // Record a row in the Notifications Center regardless of
            // outcome — "Movie scene ran (4/4)" is exactly the kind of
            // lightweight history the feed is meant to surface.
            if !scene.actions.isEmpty {
                eventStore.post(
                    kind: result.isCompleteFailure ? .alert : .automation,
                    title: "\(scene.name) scene ran",
                    message: "\(result.succeeded) of \(result.total) actions succeeded"
                )
            }
            if scene.actions.isEmpty {
                toast = .error("\(scene.name) is empty — add actions first")
            } else if result.isFullSuccess {
                // Silent success — the device tiles will animate to the
                // new state via their own observation, so a toast here
                // would double up the feedback.
            } else if result.isCompleteFailure {
                toast = .error("\(scene.name) failed: \(result.failures.first?.message ?? "unknown error")")
            } else {
                toast = .error("\(scene.name): \(result.succeeded)/\(result.total) actions succeeded")
            }
        }
    }

    /// Searchable, sorted list of rooms unified across every provider.
    /// First room per normalized name wins the tile; the rest fold into
    /// it via the sibling-room merge in RoomDetailView.
    private var dedupedRooms: [Room] {
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
        return deduped.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Counts every accessory whose room name matches this tile's name,
    /// across every provider. That's why a merged "Den" tile reads
    /// "5 devices" when it's 4 HomeKit lights + 1 Sonos speaker.
    private func deviceCount(in room: Room) -> Int {
        let matchingRoomIDs = siblingRoomIDs(matching: room)
        return registry.allAccessories.filter {
            guard let rid = $0.roomID else { return false }
            return matchingRoomIDs.contains(rid)
        }.count
    }

    /// All room IDs (across every provider) whose name matches
    /// `anchor.name` — the set that makes up a "virtual room".
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

// MARK: - Scene tile

/// One tile in the Quick Scenes horizontal row. Taps invoke the onTap
/// closure; a running scene shows a ProgressView over the glyph.
struct SceneTile: View {
    let scene: HCScene
    let isRunning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                        .fill(Theme.color.iconChipFill)
                        .frame(width: 56, height: 56)
                    if isRunning {
                        ProgressView()
                    } else {
                        Image(systemName: scene.iconSystemName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.color.iconChipGlyph)
                    }
                }
                Text(scene.name)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
            }
            .frame(width: 84)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(Theme.color.cardFill)
                    .shadow(color: Color.black.opacity(0.06),
                            radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scene.name)
        .accessibilityValue(isRunning ? "Running" : "")
        .accessibilityHint("Double tap to run scene")
        .accessibilityAddTraits(.isButton)
    }

    /// The trailing "+" tile the user taps to add a new scene. Rendered
    /// as a dashed outline instead of a filled card so it reads as an
    /// affordance rather than a real scene.
    static var newSceneTile: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                    .strokeBorder(Theme.color.primary.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(width: 56, height: 56)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.color.primary)
            }
            Text("New")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
        }
        .frame(width: 84)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .strokeBorder(Theme.color.divider, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New scene")
        .accessibilityHint("Double tap to create a new scene")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Room tile

/// Square-ish card: icon chip top-left, room name, device count below.
struct RoomTile: View {
    let room: Room
    let deviceCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconChip(systemName: RoomIcon.systemName(for: room.name), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s")")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(room.name), \(deviceCount) device\(deviceCount == 1 ? "" : "s")")
        .accessibilityHint("Double tap to view room")
        .accessibilityAddTraits(.isButton)
    }
}

/// Maps common room names to SF Symbols. Falls through to a generic
/// square icon if we don't recognize the name. Pure function — easy
/// to retune without touching view code.
enum RoomIcon {
    static func systemName(for roomName: String) -> String {
        let n = roomName.lowercased()
        if n.contains("living") { return "sofa.fill" }
        if n.contains("bed") { return "bed.double.fill" }
        if n.contains("kitchen") { return "fork.knife" }
        if n.contains("office") { return "desktopcomputer" }
        if n.contains("bath") { return "shower.fill" }
        if n.contains("garage") { return "car.fill" }
        if n.contains("dining") { return "fork.knife.circle.fill" }
        if n.contains("garden") || n.contains("yard") { return "leaf.fill" }
        if n.contains("laundry") { return "washer.fill" }
        if n.contains("hall") || n.contains("entry") { return "door.left.hand.open" }
        return "square.grid.2x2.fill"
    }
}

// MARK: - Navigation destinations

/// Enum used for typed navigation out of the dashboard into the scenes
/// flow. Keeping it enum-based means we can add "run history", "pick
/// template", etc. without new Hashable types.
enum ScenesDestination: Hashable {
    case list
    case editor(sceneID: UUID?)
}

/// Non-scene navigation pushes from Home (currently just the bell →
/// Notifications Center). A dedicated enum keeps the path typed and
/// avoids a parallel `.navigationDestination(for: String.self)`.
enum HomeDestination: Hashable {
    case notifications
}

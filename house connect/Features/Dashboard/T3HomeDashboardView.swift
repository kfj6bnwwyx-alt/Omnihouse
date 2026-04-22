//
//  T3HomeDashboardView.swift
//  house connect
//
//  T3/Swiss Home dashboard — warm cream, honest data readout.
//  Matches Claude Design handoff T3Home component.
//
//  Sections:
//    1. Masthead: home name + date
//    2. Greeting: "Good morning, Alex." + status dot
//    3. Weather strip: Outside / Inside / Energy — 3-column grid
//    4. Scenes: horizontal chip row or 2-col grid (Swiss variant)
//    5. Rooms: indexed list with glyph, name, active/total count
//

import SwiftUI

struct T3HomeDashboardView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(SceneStore.self) private var sceneStore
    @Environment(WeatherService.self) private var weather
    @Environment(AppEventStore.self) private var eventStore
    @Environment(T3TabNavigator.self) private var navigator

    @State private var selectedSceneIndex: Int = 0
    @State private var runningSceneID: UUID?
    @State private var toast: Toast?
    @State private var isEditingQuickActions: Bool = false

    /// User's display name for the greeting. Set in Settings → Profile.
    /// Empty = no personalization ("Good morning." without a comma).
    @AppStorage("profile.firstName") private var firstName: String = ""

    /// Comma-separated list of pinned scene UUIDs for the Quick Actions row.
    /// Empty string = no pins (we fall back to the first 4 scenes alphabetically).
    /// Edited via `T3QuickActionsEditSheet` (pencil icon on the section head).
    @AppStorage("dashboard.quickActionSceneIDs") private var quickActionSceneIDsRaw: String = ""

    private var rooms: [Room] {
        let allRooms = registry.allRooms
        // Deduplicate by name (same pattern as HomeDashboardView)
        var seen = Set<String>()
        return allRooms.filter { seen.insert($0.name.lowercased()).inserted }
    }

    private var activeCount: Int {
        registry.allAccessories.filter { $0.isOn == true }.count
    }

    private var offlineCount: Int {
        registry.allAccessories.filter { !$0.isReachable }.count
    }

    private var standbyCount: Int {
        registry.allAccessories.count - activeCount - offlineCount
    }

    /// Read indoor temperature from the first thermostat or climate sensor.
    private var insideTemp: String {
        if let thermo = registry.allAccessories.first(where: { $0.category == .thermostat }),
           let celsius = thermo.currentTemperature {
            let fahrenheit = Int((celsius * 9.0 / 5.0 + 32.0).rounded())
            return "\(fahrenheit)°"
        }
        return "—"
    }

    /// Read indoor humidity from a sensor or thermostat.
    private var insideHumidity: String {
        if let humidity = registry.allAccessories.compactMap({ $0.humidityPercent }).first {
            return "\(humidity)% RH"
        }
        return ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greeting
                    .t3ScreenTopPad()
                masthead
                TRule()
                weatherStrip
                TRule()
                quickActionsSection
                TRule()
                scenesSection
                TRule()
                roomsList
                TRule()
                exploreSection
                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .tint(T3.accent)
        .refreshable {
            weather.fetchIfNeeded()
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in await provider.refresh() }
                }
            }
        }
        .toast($toast)
        .sheet(isPresented: $isEditingQuickActions) {
            T3QuickActionsEditSheet()
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(spacing: 12) {
            TLabel(text: registry.allHomes.first?.name.uppercased() ?? "HOME")
            Spacer()
            TLabel(text: Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))

            // Notification bell
            NavigationLink(value: HomeDestination.notifications) {
                ZStack(alignment: .topTrailing) {
                    T3IconImage(systemName: "bell")
                        .frame(width: 18, height: 18)
                        .foregroundStyle(T3.ink)
                        .accessibilityHidden(true)
                    if eventStore.unreadCount > 0 {
                        TDot(size: 6)
                            .offset(x: 2, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(eventStore.unreadCount > 0
                                ? "Notifications, \(eventStore.unreadCount) unread"
                                : "Notifications")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.bottom, 12)
    }

    enum HomeDestination: Hashable {
        case notifications
        case energy
        case activity
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greetingAttributed)
                .font(T3.inter(36, weight: .medium))
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 10) {
                TDot(size: 8)
                    .accessibilityHidden(true)
                TLabel(text: "\(activeCount) active · \(offlineCount) offline · \(standbyCount) standby")
            }
            .padding(.top, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(activeCount) devices active, \(offlineCount) offline, \(standbyCount) on standby")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }

    /// Two-tone greeting: time-of-day in ink, optional name in sub.
    /// AttributedString replaces the deprecated `Text + Text` concatenation.
    private var greetingAttributed: AttributedString {
        let trimmed = firstName.trimmingCharacters(in: .whitespaces)
        var prefix = AttributedString("Good \(timeOfDay)")
        prefix.foregroundColor = T3.ink
        var suffix = AttributedString(trimmed.isEmpty ? "." : ", \(trimmed).")
        suffix.foregroundColor = T3.sub
        return prefix + suffix
    }

    // MARK: - Weather Strip

    private var weatherStrip: some View {
        HStack(spacing: 18) {
            if weather.isLoading {
                // Skeleton loader — shimmer bars matching the data layout
                weatherSkeleton(label: "Outside")
                weatherSkeleton(label: "Inside")
                weatherSkeleton(label: "Energy")
            } else {
                weatherCell(label: "Outside", value: weather.headline.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? "—", sub: weather.headline.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? "")
                weatherCell(label: "Inside", value: insideTemp, sub: insideHumidity)
                weatherCell(label: "Energy", value: "—", sub: "Not available", unit: nil)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 18)
    }

    private func weatherSkeleton(label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            // Shimmer bar for the big number
            RoundedRectangle(cornerRadius: 2)
                .fill(T3.rule)
                .frame(width: 70, height: 32)
                .shimmering()
            // Shimmer bar for sub text
            RoundedRectangle(cornerRadius: 2)
                .fill(T3.rule)
                .frame(width: 50, height: 10)
                .shimmering()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weatherCell(label: String, value: String, sub: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(T3.inter(38, weight: .regular))
                    .tracking(-1.4)
                    .foregroundStyle(T3.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(T3.inter(15, weight: .regular))
                        .foregroundStyle(T3.sub)
                }
            }
            Text(sub)
                .font(T3.inter(11, weight: .regular))
                .foregroundStyle(T3.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value) \(unit ?? ""), \(sub)")
    }

    // MARK: - Quick Actions

    /// Resolved list of scenes pinned for quick access.
    /// Priority:
    ///   1. Parse `quickActionSceneIDsRaw` (comma-separated UUIDs), preserve order,
    ///      skip IDs that no longer resolve to a scene.
    ///   2. If that list is empty, fall back to the first 4 scenes sorted by name
    ///      (stable + predictable until the pin/edit UI lands).
    ///   3. Cap at 4 chips so the row stays glanceable.
    private var quickActionScenes: [HCScene] {
        let all = sceneStore.scenes
        let ids: [UUID] = quickActionSceneIDsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }

        if !ids.isEmpty {
            let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            let pinned = ids.compactMap { byID[$0] }
            if !pinned.isEmpty { return Array(pinned.prefix(4)) }
        }

        return Array(all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.prefix(4))
    }

    /// Section head with a trailing pencil button that opens the edit sheet.
    /// Built inline instead of using `TSectionHead` so we can slot the
    /// pencil in the spot normally reserved for the mono count.
    private var quickActionsHeader: some View {
        HStack {
            Text("Quick Actions")
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isEditingQuickActions = true
            } label: {
                T3IconImage(systemName: "pencil")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(T3.ink)
                    .frame(minWidth: 44, minHeight: 32, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit pinned scenes")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, T3.sectionTopPad)
        .padding(.bottom, T3.sectionBottomPad)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            quickActionsHeader

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let pinned = quickActionScenes
                    if pinned.isEmpty {
                        quickActionPlaceholder
                    } else {
                        ForEach(pinned) { scene in
                            quickActionChip(scene)
                        }
                    }
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.bottom, 18)
            }
        }
    }

    private func quickActionChip(_ scene: HCScene) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            runScene(scene)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                T3IconImage(systemName: scene.iconSystemName)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(T3.ink)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Text(scene.name)
                    .font(T3.inter(12, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(width: 100, height: 72, alignment: .topLeading)
            .background(T3.panel)
            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run \(scene.name) scene")
        .accessibilityAddTraits(.isButton)
    }

    /// Placeholder chip shown when no scenes exist / are pinned.
    /// Taps route to Settings → Scenes so the user can create one.
    private var quickActionPlaceholder: some View {
        Button {
            navigator.goToSettings(.scenes)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                T3IconImage(systemName: "plus")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(T3.sub)
                Spacer(minLength: 0)
                Text("Create a scene to pin it here")
                    .font(T3.inter(11, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(width: 180, height: 72, alignment: .topLeading)
            .background(T3.panel)
            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create a scene to pin here")
    }

    // MARK: - Scenes

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Scenes", count: String(format: "%02d", sceneStore.scenes.count))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(sceneStore.scenes.enumerated()), id: \.element.id) { i, scene in
                        sceneChip(scene, index: i)
                    }
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.bottom, 18)
            }
        }
    }

    private func sceneChip(_ scene: HCScene, index: Int) -> some View {
        let selected = index == selectedSceneIndex
        return Button {
            selectedSceneIndex = index
            runScene(scene)
        } label: {
            HStack(spacing: 8) {
                T3IconImage(systemName: scene.iconSystemName)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(selected ? T3.page : T3.ink)
                    .accessibilityHidden(true)
                Text(scene.name)
                    .font(T3.inter(13, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(selected ? T3.page : T3.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selected ? T3.ink : T3.panel)
                    .overlay(
                        Capsule()
                            .stroke(selected ? .clear : T3.rule, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run \(scene.name) scene")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Active rooms (what's on + quick off)
    //
    // Home is "what's on right now"; the Rooms tab is the full spatial
    // view. This section only lists rooms with active devices, sorted by
    // active count, with a trailing "Off" action per row to match Home's
    // "know what's on, turn it off" job. Empty state = everything off.
    // "See all →" jumps to the Rooms tab for the complete list.

    private struct ActiveRoom: Identifiable {
        let room: Room
        let activeDevices: [Accessory]
        var id: String { "\(room.provider.rawValue)|\(room.id)" }
        var activeCount: Int { activeDevices.count }
    }

    private var activeRooms: [ActiveRoom] {
        let accessories = registry.allAccessories
        return rooms.compactMap { room in
            let on = accessories.filter { $0.roomID == room.id && $0.isOn == true }
            guard !on.isEmpty else { return nil }
            return ActiveRoom(room: room, activeDevices: on)
        }
        .sorted { $0.activeCount > $1.activeCount }
    }

    private var roomsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            activeRoomsHeader

            if activeRooms.isEmpty {
                HStack {
                    Text("Everything's off.")
                        .font(T3.inter(14, weight: .regular))
                        .foregroundStyle(T3.sub)
                    Spacer()
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 18)
            } else {
                ForEach(Array(activeRooms.enumerated()), id: \.element.id) { i, entry in
                    activeRoomRow(entry)
                    if i < activeRooms.count - 1 { TRule() }
                }
            }
        }
    }

    private func activeRoomRow(_ entry: ActiveRoom) -> some View {
        HStack(spacing: 14) {
            NavigationLink(value: entry.room) {
                HStack(spacing: 14) {
                    T3IconImage(systemName: roomIcon(entry.room.name))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(T3.ink)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.room.name)
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        HStack(spacing: 6) {
                            TDot(size: 6).accessibilityHidden(true)
                            Text("\(entry.activeCount) on")
                                .font(T3.mono(10))
                                .foregroundStyle(T3.sub)
                                .tracking(0.6)
                        }
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.t3Row)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.room.name), \(entry.activeCount) devices on")
            .accessibilityAddTraits(.isButton)

            Button { turnOffRoom(entry) } label: {
                Text("Off")
                    .font(T3.inter(12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(T3.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().stroke(T3.rule, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Turn off all devices in \(entry.room.name)")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
    }

    /// Fires setPower(false) for every currently-on device in the room
    /// in parallel, tolerating per-device failures so one unreachable
    /// device doesn't cancel the rest. Toast reflects the aggregate.
    private func turnOffRoom(_ entry: ActiveRoom) {
        let devices = entry.activeDevices
        let roomName = entry.room.name
        Task {
            let failures: Int = await withTaskGroup(of: Bool.self) { group in
                for device in devices {
                    group.addTask { @MainActor in
                        do {
                            try await registry.execute(.setPower(false), on: device.id)
                            return true
                        } catch {
                            return false
                        }
                    }
                }
                var failed = 0
                for await success in group where !success { failed += 1 }
                return failed
            }

            if failures == 0 {
                toast = .success("Off in \(roomName)")
            } else if failures == devices.count {
                toast = .error("Couldn't turn off \(roomName)")
            } else {
                toast = .error("\(roomName): \(devices.count - failures)/\(devices.count) off")
            }
        }
    }

    private var activeRoomsHeader: some View {
        HStack {
            Text("Active rooms")
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Spacer()
            if !activeRooms.isEmpty {
                TLabel(text: String(format: "%02d", activeRooms.count))
            }
            Button {
                navigator.select(.rooms)
            } label: {
                HStack(spacing: 4) {
                    Text("See all")
                        .font(T3.inter(12, weight: .medium))
                        .foregroundStyle(T3.sub)
                    T3IconImage(systemName: "arrow.right")
                        .frame(width: 10, height: 10)
                        .foregroundStyle(T3.sub)
                }
                .padding(.leading, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See all rooms")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, T3.sectionTopPad)
        .padding(.bottom, T3.sectionBottomPad)
    }

    private func roomIcon(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("living") || lower.contains("family") || lower.contains("den") { return "sofa.fill" }
        if lower.contains("kitchen") { return "fork.knife" }
        if lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("entry") || lower.contains("door") || lower.contains("hall") { return "door.left.hand.open" }
        if lower.contains("bath") { return "shower.fill" }
        if lower.contains("office") || lower.contains("study") { return "desktopcomputer" }
        if lower.contains("garage") { return "car.fill" }
        return "square.grid.2x2"
    }

    // MARK: - Explore (Energy + Activity)

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Explore", count: "02")

            exploreRow(icon: "bolt.fill", title: "Energy", sub: "DAILY KWH · BREAKDOWN", destination: .energy)
            exploreRow(icon: "clock.arrow.circlepath", title: "Activity", sub: "TODAY'S EVENT TIMELINE", destination: .activity, isLast: true)
        }
    }

    private func exploreRow(
        icon: String,
        title: String,
        sub: String,
        destination: HomeDestination,
        isLast: Bool = false
    ) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: 14) {
                T3IconImage(systemName: icon)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    TLabel(text: sub)
                }
                Spacer()
                T3IconImage(systemName: "arrow.right")
                    .frame(width: 14, height: 14)
                    .foregroundStyle(T3.sub)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast { TRule() }
            }
        }
        .buttonStyle(.t3Row)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(sub)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Scene execution

    private func runScene(_ scene: HCScene) {
        guard runningSceneID == nil else { return }
        guard !scene.actions.isEmpty else {
            toast = .error("\(scene.name) is empty")
            return
        }
        runningSceneID = scene.id
        Task {
            let result = await SceneRunner(registry: registry).run(scene)
            runningSceneID = nil
            if result.isFullSuccess {
                toast = .success("\(scene.name) ran")
            } else {
                toast = .error("\(scene.name): \(result.succeeded)/\(result.total)")
            }
        }
    }
}

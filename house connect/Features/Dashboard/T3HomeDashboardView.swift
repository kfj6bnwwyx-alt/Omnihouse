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

    @State private var selectedSceneIndex: Int = 0
    @State private var runningSceneID: UUID?
    @State private var toast: Toast?

    /// User's display name for the greeting. Set in Settings → Profile.
    /// Empty = no personalization ("Good morning." without a comma).
    @AppStorage("profile.firstName") private var firstName: String = ""

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
                masthead
                greeting
                TRule()
                weatherStrip
                TRule()
                scenesSection
                TRule()
                roomsList
                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .refreshable {
            weather.fetchIfNeeded()
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in await provider.refresh() }
                }
            }
        }
        .toast($toast)
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
                    if eventStore.unreadCount > 0 {
                        TDot(size: 6)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 8)
    }

    enum HomeDestination: Hashable {
        case notifications
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greetingAttributed)
                .font(T3.inter(36, weight: .medium))
                .tracking(-1)

            HStack(spacing: 10) {
                TDot(size: 8)
                TLabel(text: "\(activeCount) active · \(offlineCount) offline · \(standbyCount) standby")
            }
            .padding(.top, 6)
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
                Text(scene.name)
                    .font(T3.inter(13, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(selected ? T3.page : T3.ink)
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
    }

    // MARK: - Rooms (2-column grid)

    private var roomsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Rooms", count: String(format: "%02d", rooms.count))

            // 2-column grid — rooms as spatial zones, not a flat list
            let columns = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                    let deviceCount = registry.allAccessories.filter { $0.roomID == room.id }.count
                    let activeDevices = registry.allAccessories.filter { $0.roomID == room.id && $0.isOn == true }.count

                    NavigationLink(value: room) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Top: glyph + index
                            HStack {
                                T3IconImage(systemName: roomIcon(room.name))
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(T3.ink)
                                Spacer()
                                TLabel(text: String(format: "%02d", i + 1))
                            }

                            Spacer()

                            // Bottom: name + active status
                            VStack(alignment: .leading, spacing: 6) {
                                Text(room.name)
                                    .font(T3.inter(18, weight: .medium))
                                    .tracking(-0.4)
                                    .foregroundStyle(T3.ink)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    if activeDevices > 0 { TDot(size: 6) }
                                    Text("\(activeDevices)/\(deviceCount) on")
                                        .font(T3.mono(10))
                                        .foregroundStyle(T3.sub)
                                        .tracking(0.6)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(minHeight: 140)
                        .overlay(alignment: .bottom) {
                            TRule()
                        }
                        .overlay(alignment: .trailing) {
                            if i % 2 == 0 {
                                Rectangle().fill(T3.rule).frame(width: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

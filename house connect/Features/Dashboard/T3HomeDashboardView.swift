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

    @State private var selectedSceneIndex: Int = 0

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
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack {
            TLabel(text: registry.allHomes.first?.name.uppercased() ?? "HOME")
            Spacer()
            TLabel(text: Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 8)
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Good \(timeOfDay),")
                .font(T3.inter(36, weight: .medium))
                .tracking(-1)
                .foregroundStyle(T3.ink)
            +
            Text(" Alex.")
                .font(T3.inter(36, weight: .medium))
                .tracking(-1)
                .foregroundStyle(T3.sub)

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

    // MARK: - Weather Strip

    private var weatherStrip: some View {
        HStack(spacing: 18) {
            weatherCell(label: "Outside", value: weather.headline.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? "—", sub: weather.headline.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? "")
            weatherCell(label: "Inside", value: "68°", sub: "42% RH")
            weatherCell(label: "Energy", value: "1.4", sub: "Today", unit: "kW")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 18)
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
                .font(.system(size: 11))
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
        } label: {
            HStack(spacing: 8) {
                Image(systemName: scene.iconSystemName)
                    .font(.system(size: 14, weight: .medium))
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

    // MARK: - Rooms

    private var roomsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Rooms", count: String(format: "%02d", rooms.count))

            ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                let deviceCount = registry.allAccessories.filter { $0.roomID == room.id }.count
                let activeDevices = registry.allAccessories.filter { $0.roomID == room.id && $0.isOn == true }.count

                NavigationLink(value: room) {
                    HStack(spacing: 14) {
                        TLabel(text: String(format: "%02d", i + 1))
                            .frame(width: 28)

                        Image(systemName: roomIcon(room.name))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .frame(width: 28)

                        Text(room.name)
                            .font(T3.inter(15, weight: .medium))
                            .tracking(-0.2)
                            .foregroundStyle(T3.ink)

                        Spacer()

                        HStack(spacing: 8) {
                            if activeDevices > 0 { TDot(size: 6) }
                            Text("\(activeDevices)/\(deviceCount)")
                                .font(T3.mono(12))
                                .foregroundStyle(T3.sub)
                                .monospacedDigit()
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(T3.sub)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, T3.rowVerticalPad)
                    .overlay(alignment: .top) {
                        TRule()
                    }
                    .overlay(alignment: .bottom) {
                        if i == rooms.count - 1 { TRule() }
                    }
                }
                .buttonStyle(.plain)
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
        return "square.grid.2x2.fill"
    }
}

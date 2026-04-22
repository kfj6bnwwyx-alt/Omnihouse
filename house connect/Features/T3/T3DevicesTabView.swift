//
//  T3DevicesTabView.swift
//  house connect
//
//  T3/Swiss Devices tab — flat filterable list with search + category chips.
//

import SwiftUI

struct T3DevicesTabView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(T3TabNavigator.self) private var navigator
    @Environment(DeviceLinkStore.self) private var linkStore

    @State private var filter: String = "All"
    @State private var searchQuery: String = ""
    @FocusState private var searchFocused: Bool
    @State private var showAddDeviceSheet: Bool = false
    /// When true, cross-provider duplicates are collapsed using
    /// DeviceMerging + DeviceLinkStore. Persisted so the user's
    /// preference survives tab switches.
    @AppStorage("devices.mergedMode") private var mergedMode: Bool = false
    /// Short settle gate so the empty state doesn't flash during the
    /// first render before provider accessories stream in. See the
    /// matching comment in T3RoomsTabView.
    @State private var didSettle = false

    /// Category chip -> set of `Accessory.Category` values. "All" is a
    /// sentinel that skips category filtering entirely. "Sensors" collects
    /// sensors + smoke alarms since they share the same "thing that reports"
    /// mental model; "Security" groups locks + cameras.
    private let filters = ["All", "Lights", "Climate", "Security", "Media", "Sensors"]

    private func categories(for chip: String) -> Set<Accessory.Category>? {
        switch chip {
        case "Lights":   return [.light, .switch, .outlet]
        case "Climate":  return [.thermostat, .fan]
        case "Security": return [.lock, .camera]
        case "Media":    return [.speaker, .television, .appleTV]
        case "Sensors":  return [.sensor, .smokeAlarm]
        default:         return nil // "All"
        }
    }

    /// Room name lookup so search can match "Living Room" etc.
    private func roomName(for id: String?) -> String? {
        guard let id else { return nil }
        return registry.allRooms.first(where: { $0.id == id })?.name
    }

    private var totalCount: Int { registry.allAccessories.count }

    /// Preference order for merged-device representative selection.
    private let preferenceOrder: [ProviderID] = [
        .homeKit, .homeAssistant, .smartThings, .sonos, .nest
    ]

    /// In Merged mode, the deduped list. The representative (primary)
    /// accessory for each merged bucket is used for display and routing.
    private var mergedAccessories: [Accessory] {
        let resolver: (Accessory) -> String? = { [registry] acc in
            registry.allRooms.first(where: { $0.id == acc.roomID })?.name
        }
        let merged = DeviceMerging.merge(
            accessories: registry.allAccessories,
            preferenceOrder: preferenceOrder,
            roomNameResolver: resolver,
            forcedLinks: linkStore.links
        )
        // Return the representative Accessory for each merged device.
        return merged.compactMap { mergedDevice in
            registry.allAccessories.first(where: { $0.id == mergedDevice.preferredID })
        }
    }

    private var devices: [Accessory] {
        let all: [Accessory]
        if mergedMode {
            all = mergedAccessories.sorted { $0.name < $1.name }
        } else {
            all = registry.allAccessories.sorted { $0.name < $1.name }
        }

        // Category filter
        let categoryFiltered: [Accessory]
        if let allowed = categories(for: filter) {
            categoryFiltered = all.filter { allowed.contains($0.category) }
        } else {
            categoryFiltered = all
        }

        // Search filter (name + category label + room name, case-insensitive substring)
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return categoryFiltered }
        let q = trimmed.lowercased()
        return categoryFiltered.filter { acc in
            if acc.name.lowercased().contains(q) { return true }
            if acc.category.displayLabel.lowercased().contains(q) { return true }
            if let r = roomName(for: acc.roomID), r.lowercased().contains(q) { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: "Devices.",
                    subtitle: "\(registry.allAccessories.filter { $0.isOn == true }.count) on now · across \(registry.allRooms.count) rooms"
                )
                .t3ScreenTopPad()

                // Search bar
                searchBar
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 12)

                // Filter chips + merged toggle
                HStack(alignment: .center, spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { f in
                                Button {
                                    filter = (filter == f && f != "All") ? "All" : f
                                } label: {
                                    Text(f)
                                        .font(T3.inter(13, weight: .medium))
                                        .foregroundStyle(filter == f ? T3.page : T3.ink)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(filter == f ? T3.ink : .clear)
                                                .overlay(
                                                    Capsule().stroke(filter == f ? .clear : T3.rule, lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(f) category filter")
                                .accessibilityAddTraits(filter == f ? .isSelected : [])
                            }
                        }
                        .padding(.leading, T3.screenPadding)
                        .padding(.bottom, 10)
                    }

                    // Merged mode toggle — collapses cross-provider duplicates
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { mergedMode.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            T3IconImage(systemName: mergedMode ? "link" : "link.badge.plus")
                                .frame(width: 12, height: 12)
                                .foregroundStyle(mergedMode ? T3.page : T3.sub)
                            Text("Merged")
                                .font(T3.inter(12, weight: .medium))
                                .foregroundStyle(mergedMode ? T3.page : T3.sub)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(mergedMode ? T3.ink : Color.clear)
                        .overlay(
                            Capsule().stroke(mergedMode ? Color.clear : T3.rule, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Merged mode \(mergedMode ? "on" : "off")")
                    .accessibilityAddTraits(mergedMode ? .isSelected : [])
                    .padding(.trailing, T3.screenPadding)
                    .padding(.bottom, 10)
                }

                // Result count badge — only show when we have devices at all
                if totalCount > 0 {
                    let displayCount = devices.count
                    HStack(spacing: 6) {
                        Text("\(displayCount)\(mergedMode ? " merged" : "") of \(totalCount) devices")
                            .font(T3.mono(10))
                            .foregroundStyle(T3.sub)
                        if mergedMode && !linkStore.links.isEmpty {
                            Text("·")
                                .font(T3.mono(10))
                                .foregroundStyle(T3.sub)
                            Text("\(linkStore.links.count) manual link\(linkStore.links.count == 1 ? "" : "s")")
                                .font(T3.mono(10))
                                .foregroundStyle(T3.accent)
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 12)
                    .accessibilityLabel("Showing \(displayCount) of \(totalCount) devices")
                }

                // Empty states — order matters.
                if registry.allAccessories.isEmpty && didSettle {
                    // No devices connected at all.
                    T3EmptyState(
                        iconSystemName: "server",
                        title: "No devices connected",
                        subtitle: "Connect Home Assistant in Settings to see your devices here.",
                        actionTitle: "Open Settings",
                        action: { navigator.goToSettings(.providers) }
                    )
                } else if devices.isEmpty && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Query non-empty but nothing matches.
                    T3EmptyState(
                        iconSystemName: "magnifyingglass",
                        title: "No matches for \"\(searchQuery)\"",
                        subtitle: "Try a different name, category, or room.",
                        actionTitle: "Clear search",
                        action: {
                            searchQuery = ""
                            searchFocused = false
                        }
                    )
                } else if devices.isEmpty && filter != "All" {
                    // Query empty, but category filter yields nothing.
                    T3EmptyState(
                        iconSystemName: "server",
                        title: "No \(filter.lowercased()) devices",
                        subtitle: "Nothing in this category yet.",
                        actionTitle: "Show all",
                        action: { filter = "All" }
                    )
                }

                // Device rows — tap navigates to detail
                ForEach(Array(devices.enumerated()), id: \.element.id) { i, device in
                    NavigationLink(value: device.id) {
                        T3DeviceRow(device: device, index: i, isLast: i == devices.count - 1)
                    }
                    .buttonStyle(.t3Row)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(device.name), \(device.category.displayLabel), \(device.isOn == true ? "on" : (device.isReachable ? "off" : "offline"))")
                    .accessibilityAddTraits(.isButton)
                }

                // Add device dashed button
                Button { showAddDeviceSheet = true } label: {
                    HStack {
                        T3IconImage(systemName: "plus")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(T3.sub)
                            .accessibilityHidden(true)
                        Text("Add device")
                            .font(T3.inter(14, weight: .medium))
                            .foregroundStyle(T3.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle()
                            .stroke(T3.rule, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add device")
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 16)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .tint(T3.accent)
        .task {
            guard !didSettle else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            didSettle = true
        }
        .refreshable {
            await withTaskGroup(of: Void.self) { group in
                for provider in registry.providers {
                    group.addTask { @MainActor in await provider.refresh() }
                }
            }
        }
        .sheet(isPresented: $showAddDeviceSheet) {
            T3AddDeviceSheet(onOpenConnections: {
                navigator.goToSettings(.providers)
            })
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            T3IconImage(systemName: "magnifyingglass")
                .frame(width: 14, height: 14)
                .foregroundStyle(T3.sub)
                .accessibilityHidden(true)

            TextField("", text: $searchQuery, prompt: Text("Search devices").foregroundColor(T3.sub))
                .font(T3.inter(14))
                .foregroundStyle(T3.ink)
                .tint(T3.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .focused($searchFocused)
                .accessibilityLabel("Search devices")

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchFocused = true
                } label: {
                    T3IconImage(systemName: "xmark")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(T3.sub)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .stroke(T3.rule, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }
}

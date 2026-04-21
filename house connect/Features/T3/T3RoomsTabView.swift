//
//  T3RoomsTabView.swift
//  house connect
//
//  T3/Swiss Rooms tab — 2-column grid of room cards, no rounding.
//

import SwiftUI

struct T3RoomsTabView: View {
    @Environment(ProviderRegistry.self) private var registry
    @State private var showingCreate = false
    /// Short post-appearance gate so the empty state doesn't flash
    /// during the first render, before provider rooms stream in.
    /// `ProviderRegistry` has no `isLoading` flag to hang this on, so
    /// we use a 400ms delay — short enough to feel instant when there
    /// genuinely are zero rooms, long enough to avoid the flash.
    @State private var didSettle = false

    private var rooms: [Room] {
        var seen = Set<String>()
        return registry.allRooms.filter { seen.insert($0.name.lowercased()).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: "Rooms.",
                    subtitle: "\(registry.allAccessories.filter { $0.isOn == true }.count) devices active across the house"
                )
                .t3ScreenTopPad()

                if rooms.isEmpty && didSettle {
                    T3EmptyState(
                        iconSystemName: "sofa.fill",
                        title: "No rooms yet",
                        subtitle: "Create a room to organize your devices.",
                        actionTitle: "Create Room",
                        action: { showingCreate = true }
                    )
                }

                // 2-column grid
                let columns = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                        let deviceCount = registry.allAccessories.filter { $0.roomID == room.id }.count
                        let activeCount = registry.allAccessories.filter { $0.roomID == room.id && $0.isOn == true }.count

                        NavigationLink(value: room) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    T3IconImage(systemName: roomIcon(room.name))
                                        .frame(width: 22, height: 22)
                                        .foregroundStyle(T3.ink)
                                        .accessibilityHidden(true)
                                    Spacer()
                                    TLabel(text: String(format: "%02d", i + 1))
                                        .accessibilityHidden(true)
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(room.name)
                                        .font(T3.inter(18, weight: .medium))
                                        .foregroundStyle(T3.ink)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    HStack(spacing: 6) {
                                        if activeCount > 0 { TDot(size: 6) }
                                        Text("\(activeCount)/\(deviceCount) on")
                                            .font(T3.mono(10))
                                            .foregroundStyle(T3.sub)
                                            .tracking(0.6)
                                    }
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 20)
                            .frame(minHeight: 150)
                            .overlay(alignment: .bottom) { TRule() }
                            .overlay(alignment: .trailing) {
                                if i % 2 == 0 {
                                    Rectangle().fill(T3.rule).frame(width: 1)
                                }
                            }
                        }
                        .buttonStyle(.t3Row)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(room.name), \(activeCount) of \(deviceCount) devices on")
                        .accessibilityAddTraits(.isButton)
                    }
                }

                // New room dashed button
                Button { showingCreate = true } label: {
                    HStack {
                        T3IconImage(systemName: "plus")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(T3.sub)
                            .accessibilityHidden(true)
                        Text("New room")
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
                .accessibilityLabel("Create new room")
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 16)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
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
        .sheet(isPresented: $showingCreate) {
            T3CreateRoomSheet()
                .environment(registry)
        }
    }

    private func roomIcon(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("living") || lower.contains("family") || lower.contains("den") { return "sofa.fill" }
        if lower.contains("kitchen") { return "fork.knife" }
        if lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("entry") || lower.contains("door") { return "door.left.hand.open" }
        return "square.grid.2x2.fill"
    }
}

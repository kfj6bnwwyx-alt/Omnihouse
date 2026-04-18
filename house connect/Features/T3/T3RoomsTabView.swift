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

    private var rooms: [Room] {
        var seen = Set<String>()
        return registry.allRooms.filter { seen.insert($0.name.lowercased()).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    TLabel(text: "Your Home")
                    Spacer()
                    TLabel(text: String(format: "%02d rooms", rooms.count))
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 8)

                TTitle(
                    title: "Rooms.",
                    subtitle: "\(registry.allAccessories.filter { $0.isOn == true }.count) devices active across the house"
                )

                // 2-column grid
                let columns = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                        let deviceCount = registry.allAccessories.filter { $0.roomID == room.id }.count
                        let activeCount = registry.allAccessories.filter { $0.roomID == room.id && $0.isOn == true }.count

                        NavigationLink(value: room) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Image(systemName: roomIcon(room.name))
                                        .font(T3.inter(22, weight: .medium))
                                        .foregroundStyle(T3.ink)
                                    Spacer()
                                    TLabel(text: String(format: "%02d", i + 1))
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(room.name)
                                        .font(T3.inter(18, weight: .medium))
                                        .foregroundStyle(T3.ink)

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
                    }
                }

                // New room dashed button
                Button { showingCreate = true } label: {
                    HStack {
                        T3IconImage(systemName: "plus")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(T3.sub)
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
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 16)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
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

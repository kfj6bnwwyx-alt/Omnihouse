//
//  T3QuickActionsEditSheet.swift
//  house connect
//
//  Sheet for editing the Quick Actions row on T3HomeDashboardView.
//  Lets the user pick up to 4 scenes to pin, preserving selection order
//  so chip order on the dashboard reflects the order scenes were tapped.
//
//  Writes back to @AppStorage("dashboard.quickActionSceneIDs") as a
//  comma-separated list of scene UUIDs. Matches the parse path in
//  T3HomeDashboardView.quickActionScenes.
//
//  T3 Swiss aesthetic: no cards, hairline rules, monospaced order badges,
//  orange accent reserved for the filled selection state and the Done label.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3QuickActionsEditSheet: View {
    @Environment(SceneStore.self) private var sceneStore
    @Environment(T3TabNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss

    /// Max number of pinned scenes. Matches the cap in
    /// `T3HomeDashboardView.quickActionScenes` (prefix(4)).
    private let maxPinned = 4

    /// Working selection, ordered by tap order. Seeded from AppStorage on
    /// first render so the sheet reflects the current dashboard state.
    @State private var selectedIDs: [UUID] = []
    @State private var didInitialize = false

    /// Same AppStorage key used by the dashboard. Writing here triggers a
    /// dashboard re-render because @AppStorage values are observable.
    @AppStorage("dashboard.quickActionSceneIDs") private var quickActionSceneIDsRaw: String = ""

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                if sceneStore.scenes.isEmpty {
                    Spacer(minLength: 0)
                    T3EmptyState(
                        iconSystemName: "sparkles",
                        title: "No scenes yet",
                        subtitle: "Create a scene first, then come back to pin it here.",
                        actionTitle: "Create a scene",
                        action: {
                            dismiss()
                            navigator.goToSettings(.scenes)
                        }
                    )
                    Spacer(minLength: 0)
                } else {
                    TTitle(
                        title: "Pin Scenes.",
                        subtitle: "Choose up to \(maxPinned) scenes to pin to your dashboard."
                    )

                    TSectionHead(
                        title: "Scenes",
                        count: String(format: "%02d / %02d", selectedIDs.count, maxPinned)
                    )

                    ScrollView {
                        VStack(spacing: 0) {
                            let scenes = sortedScenes
                            ForEach(Array(scenes.enumerated()), id: \.element.id) { i, scene in
                                sceneRow(scene)
                                    .overlay(alignment: .top) { TRule() }
                                    .overlay(alignment: .bottom) {
                                        if i == scenes.count - 1 { TRule() }
                                    }
                            }
                            Spacer(minLength: 24)
                            clearAllButton
                            Spacer(minLength: 120)
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true
            selectedIDs = parseStoredIDs()
                .filter { id in sceneStore.scenes.contains(where: { $0.id == id }) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                TLabel(text: "Cancel", color: T3.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: saveAndDismiss) {
                TLabel(text: "Done", color: T3.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
    }

    // MARK: - Scene row

    /// Scenes sorted alphabetically so the picker is stable regardless of
    /// the order scenes happen to sit in storage. Selection order is
    /// tracked separately in `selectedIDs` and shown via the order badge.
    private var sortedScenes: [HCScene] {
        sceneStore.scenes.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func sceneRow(_ scene: HCScene) -> some View {
        let orderIndex = selectedIDs.firstIndex(of: scene.id)
        let isSelected = orderIndex != nil

        return Button {
            toggle(scene)
        } label: {
            HStack(spacing: 14) {
                // Checkbox indicator
                ZStack {
                    Rectangle()
                        .stroke(isSelected ? T3.ink : T3.rule, lineWidth: 1)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Rectangle()
                            .fill(T3.ink)
                            .frame(width: 12, height: 12)
                    }
                }
                .frame(width: 28)

                // Scene icon
                T3IconImage(systemName: scene.iconSystemName)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)

                // Scene name
                Text(scene.name)
                    .font(T3.inter(15, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                // Order badge, only when selected
                if let orderIndex {
                    Text(String(format: "%02d", orderIndex + 1))
                        .font(T3.mono(11))
                        .tracking(1)
                        .foregroundStyle(T3.accent)
                }
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Clear all

    private var clearAllButton: some View {
        HStack {
            Spacer()
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                selectedIDs.removeAll()
            } label: {
                Text("Clear all")
                    .font(T3.inter(13, weight: .medium))
                    .foregroundStyle(selectedIDs.isEmpty ? T3.sub : T3.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .stroke(T3.rule, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Selection

    private func toggle(_ scene: HCScene) {
        if let idx = selectedIDs.firstIndex(of: scene.id) {
            selectedIDs.remove(at: idx)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            return
        }
        if selectedIDs.count >= maxPinned {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
            return
        }
        selectedIDs.append(scene.id)
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    // MARK: - Persistence

    private func parseStoredIDs() -> [UUID] {
        quickActionSceneIDsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }
    }

    private func saveAndDismiss() {
        quickActionSceneIDsRaw = selectedIDs.map { $0.uuidString }.joined(separator: ",")
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }
}

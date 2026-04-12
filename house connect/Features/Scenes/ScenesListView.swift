//
//  ScenesListView.swift
//  house connect
//
//  Full list of scenes with add / edit / delete. Reached from the "+" tile
//  on the home dashboard's Quick Scenes row (and eventually from a
//  Settings "Scenes" deep link once we rebuild Settings).
//
//  Redesigned to match the card-based visual language of the rest of the
//  app (AllRoomsView, AllDevicesView, etc.) instead of the old
//  `.insetGrouped` Form chrome. Each scene is a horizontal card with
//  an icon chip, name, action count, and a run button. Long-press offers
//  delete via a context menu. The "+ New Scene" CTA follows the same
//  dashed-outline pattern as the dashboard's "New" scene tile.
//

import SwiftUI

struct ScenesListView: View {
    @Environment(SceneStore.self) private var sceneStore
    @Environment(ProviderRegistry.self) private var registry

    @Environment(\.dismiss) private var dismiss

    @State private var runningSceneID: UUID?
    @State private var toast: Toast?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                    .padding(.top, 8)
                scenesList
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
    }

    // MARK: - Header

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

            VStack(alignment: .leading, spacing: 4) {
                Text("Scenes")
                    .font(Theme.font.screenTitle)
                    .foregroundStyle(Theme.color.title)
                Text("\(sceneStore.scenes.count) scene\(sceneStore.scenes.count == 1 ? "" : "s")")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            NavigationLink(value: ScenesDestination.editor(sceneID: nil)) {
                ZStack {
                    Circle()
                        .fill(Theme.color.primary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel("New scene")
            .accessibilityHint("Double tap to create a new scene")
        }
    }

    // MARK: - Scene list

    @ViewBuilder
    private var scenesList: some View {
        if sceneStore.scenes.isEmpty {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.color.iconChipFill)
                        .frame(width: 80, height: 80)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.color.iconChipGlyph)
                }
                VStack(spacing: 4) {
                    Text("No scenes yet")
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text("Scenes let you control multiple devices with a single tap. Create your first one with the + button above.")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No scenes yet. Scenes let you control multiple devices with a single tap. Create your first one with the plus button above.")
        } else {
            VStack(spacing: 12) {
                ForEach(sceneStore.scenes) { scene in
                    SceneCardRow(
                        scene: scene,
                        isRunning: runningSceneID == scene.id,
                        onRun: { run(scene) }
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(scene.name), \(scene.actions.count) action\(scene.actions.count == 1 ? "" : "s")")
                    .accessibilityHint("Double tap to edit. Long press for more options.")
                    .contextMenu {
                        NavigationLink(value: ScenesDestination.editor(sceneID: scene.id)) {
                            Label("Edit", systemImage: "pencil")
                        }
                        .accessibilityLabel("Edit \(scene.name)")
                        .accessibilityHint("Double tap to edit this scene")
                        Button(role: .destructive) {
                            sceneStore.remove(id: scene.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete \(scene.name)")
                        .accessibilityHint("Double tap to delete this scene")
                    }
                }
            }
        }
    }

    // MARK: - Run scene

    private func run(_ scene: HCScene) {
        guard runningSceneID == nil else { return }
        runningSceneID = scene.id
        Task {
            let result = await SceneRunner(registry: registry).run(scene)
            runningSceneID = nil
            if scene.actions.isEmpty {
                toast = .error("\(scene.name) is empty — add actions first")
            } else if result.isFullSuccess {
                toast = .success("\(scene.name) ran successfully")
            } else if result.isCompleteFailure {
                toast = .error("\(scene.name) failed: \(result.failures.first?.message ?? "unknown error")")
            } else {
                toast = .error("\(scene.name): \(result.succeeded)/\(result.total) actions succeeded")
            }
        }
    }
}

// MARK: - Scene card row

/// Horizontal card: icon chip + name/action-count + run button.
/// Tapping the card body navigates to the editor; the Run button is
/// a separate hit target that executes the scene immediately.
private struct SceneCardRow: View {
    let scene: HCScene
    let isRunning: Bool
    let onRun: () -> Void

    var body: some View {
        NavigationLink(value: ScenesDestination.editor(sceneID: scene.id)) {
            HStack(spacing: 14) {
                IconChip(systemName: scene.iconSystemName, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.name)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text("\(scene.actions.count) action\(scene.actions.count == 1 ? "" : "s")")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                }

                Spacer()

                Button(action: onRun) {
                    ZStack {
                        Circle()
                            .fill(Theme.color.primary.opacity(0.12))
                            .frame(width: 40, height: 40)
                        if isRunning {
                            ProgressView()
                                .tint(Theme.color.primary)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.color.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
                .accessibilityLabel(isRunning ? "Running \(scene.name)" : "Run \(scene.name)")
                .accessibilityHint(isRunning ? "" : "Double tap to run this scene")
                .accessibilityValue(isRunning ? "In progress" : "")
                .accessibilityAddTraits(.isButton)
                .accessibilityRemoveTraits(isRunning ? .isButton : [])
            }
            .hcCard()
        }
        .buttonStyle(.plain)
    }
}

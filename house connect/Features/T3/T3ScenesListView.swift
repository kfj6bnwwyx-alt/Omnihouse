//
//  T3ScenesListView.swift
//  house connect
//
//  T3/Swiss scenes list — indexed scene rows with run buttons.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3ScenesListView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(SceneStore.self) private var sceneStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var runningSceneID: UUID?
    @State private var doneSceneID: UUID?
    @State private var ringSceneID: UUID?
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0.25
    @State private var runProgress: (done: Int, total: Int) = (0, 0)
    @State private var toast: Toast?
    @State private var showCreateSceneSheet: Bool = false

    // MARK: - Row management state
    //
    // The scenes list used to be read-only; these states back the swipe
    // actions added in CC Wave. We use a context menu rather than
    // SwiftUI `.swipeActions` because the rows live inside a ScrollView
    // / VStack rather than a `List` — swipeActions only works on List
    // rows, and restructuring the list breaks the existing run-chip
    // overlays. Long-press → menu with Rename / Duplicate / Delete
    // matches the interaction surface we wanted without refactoring
    // the layout.
    @State private var renameTarget: HCScene?
    @State private var renameText: String = ""
    @State private var deleteTarget: HCScene?
    /// Pending-undo snapshot for the most recently deleted scene. Held
    /// for 10 seconds in an inline banner at the bottom of the screen;
    /// after that it drops to nil and the delete is permanent.
    @State private var undoState: UndoState?
    @State private var undoDismissTask: Task<Void, Never>?

    /// Snapshot of a just-deleted scene plus the index it was at, so
    /// "Undo" can put it back in the same spot. Storing the whole
    /// `HCScene` (not just the ID) means the scene stays restorable
    /// even though SceneStore has already removed + re-saved the file.
    private struct UndoState: Equatable {
        let scene: HCScene
        let index: Int
    }
    /// Scene + result pair presented in the detail sheet when a run
    /// finishes with partial or full failure. Kept as a tuple-wrapped
    /// Identifiable so SwiftUI can drive `.sheet(item:)`.
    @State private var pendingResult: PendingResult?

    /// Wraps scene + result for sheet presentation. Identified by the
    /// scene ID so presenting twice in a row (second run, new failure)
    /// correctly replaces the sheet contents.
    private struct PendingResult: Identifiable {
        let scene: HCScene
        let result: SceneRunResult
        var id: UUID { scene.id }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Home", onBack: { dismiss() })
                    TTitle(title: "Scenes.", subtitle: "\(sceneStore.scenes.count) scenes configured")

                    if sceneStore.scenes.isEmpty {
                        emptyState
                    }

                    ForEach(Array(sceneStore.scenes.enumerated()), id: \.element.id) { i, scene in
                        HStack(spacing: 14) {
                            TLabel(text: String(format: "%02d", i + 1))
                                .frame(width: 28)

                            T3IconImage(systemName: scene.iconSystemName)
                                .frame(width: 18, height: 18)
                                .foregroundStyle(T3.ink)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(scene.name)
                                    .font(T3.inter(15, weight: .medium))
                                    .tracking(-0.2)
                                    .foregroundStyle(T3.ink)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                TLabel(text: "\(scene.actions.count) actions")
                            }

                            Spacer()

                            // Run button
                            Button {
                                runScene(scene)
                            } label: {
                                runChipLabel(for: scene)
                            }
                            .buttonStyle(.plain)
                            .overlay(
                                // One-shot completion ring
                                Group {
                                    if ringSceneID == scene.id {
                                        Circle()
                                            .stroke(T3.accent, lineWidth: 2)
                                            .frame(width: 80, height: 80)
                                            .scaleEffect(ringScale)
                                            .opacity(ringOpacity)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) {
                            if i == sceneStore.scenes.count - 1 { TRule() }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                beginRename(scene)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button {
                                duplicateScene(scene)
                            } label: {
                                Label("Duplicate", systemImage: "square.on.square")
                            }
                            Button(role: .destructive) {
                                deleteTarget = scene
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    // Add scene dashed button
                    Button { showCreateSceneSheet = true } label: {
                        HStack {
                            T3IconImage(systemName: "plus")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(T3.sub)
                            Text("Add scene")
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast)
        .overlay(alignment: .bottom) {
            if let undo = undoState {
                undoBanner(for: undo)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82),
                   value: undoState)
        .sheet(isPresented: $showCreateSceneSheet) {
            T3SceneEditorView()
        }
        .sheet(item: $pendingResult) { pending in
            T3SceneRunResultSheet(scene: pending.scene, result: pending.result)
        }
        .alert("Delete \u{201C}\(deleteTarget?.name ?? "")\u{201D}?",
               isPresented: deleteAlertBinding,
               presenting: deleteTarget) { scene in
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) { performDelete(scene) }
        } message: { _ in
            Text("This scene will be removed. You can undo within 10 seconds.")
        }
        .alert("Rename scene",
               isPresented: renameAlertBinding,
               presenting: renameTarget) { _ in
            TextField("Scene name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") { commitRename() }
        } message: { scene in
            Text("Enter a new name for \u{201C}\(scene.name)\u{201D}.")
        }
    }

    // MARK: - Row action handlers

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private func beginRename(_ scene: HCScene) {
        renameText = scene.name
        renameTarget = scene
    }

    private func commitRename() {
        guard let target = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renameTarget = nil
        guard !trimmed.isEmpty, trimmed != target.name else { return }
        var updated = target
        updated.name = trimmed
        sceneStore.update(updated)
        toast = .success("Renamed")
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func duplicateScene(_ scene: HCScene) {
        _ = sceneStore.duplicate(scene)
        toast = .success("Scene duplicated")
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func performDelete(_ scene: HCScene) {
        // Capture original index before removal so undo restores the
        // scene at the same spot — inserting at the end would feel
        // like a reorder bug.
        guard let index = sceneStore.scenes.firstIndex(where: { $0.id == scene.id }) else {
            deleteTarget = nil
            return
        }
        sceneStore.remove(id: scene.id)
        deleteTarget = nil
        undoDismissTask?.cancel()
        undoState = UndoState(scene: scene, index: index)
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
        // 10-second window, matching iOS system "undo" affordances
        // (Mail swipe-to-archive is ~5s, but users asked for a longer
        // grace period on destructive scene edits).
        let snapshot = undoState
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled, undoState == snapshot {
                undoState = nil
            }
        }
    }

    private func undoDelete() {
        guard let undo = undoState else { return }
        sceneStore.insert(undo.scene, at: undo.index)
        undoDismissTask?.cancel()
        undoDismissTask = nil
        undoState = nil
        toast = .success("Scene restored")
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Bottom-anchored undo banner with a UNDO button. Styled to match
    /// the T3 aesthetic — ink background, panel-color text, single
    /// hairline rule — so it doesn't visually fight the green/red
    /// success/error toasts that float at the top of the screen.
    @ViewBuilder
    private func undoBanner(for undo: UndoState) -> some View {
        HStack(spacing: 12) {
            Text("Scene deleted")
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.panel)
            Spacer()
            Button {
                undoDelete()
            } label: {
                Text("UNDO")
                    .font(T3.mono(11))
                    .tracking(1)
                    .foregroundStyle(T3.panel)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle()
                            .stroke(T3.panel, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T3.ink)
        .padding(.horizontal, T3.screenPadding)
        .padding(.bottom, 24)
    }

    // MARK: - Empty state

    /// T3-styled blank state rendered when the user has no scenes.
    /// Kept deliberately monochrome — the `+` add-scene affordance
    /// below (dashed rectangle) already carries the call to action.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No scenes yet")
                .font(T3.inter(18, weight: .medium))
                .tracking(-0.4)
                .foregroundStyle(T3.ink)
            Text("Tap + to create your first scene")
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 56)
    }

    @ViewBuilder
    private func runChipLabel(for scene: HCScene) -> some View {
        let total = scene.actions.count
        if doneSceneID == scene.id {
            Text(String(format: "DONE · %02d/%02d", total, total))
                .font(T3.mono(11))
                .tracking(1)
                .foregroundStyle(T3.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .stroke(T3.accent, lineWidth: 1)
                )
        } else if runningSceneID == scene.id {
            Text(String(format: "RUNNING · %02d/%02d", runProgress.done, max(runProgress.total, total)))
                .font(T3.mono(11))
                .tracking(1)
                .foregroundStyle(T3.sub)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .stroke(T3.rule, lineWidth: 1)
                )
        } else {
            Text("RUN")
                .font(T3.mono(11))
                .tracking(1)
                .foregroundStyle(T3.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .stroke(T3.ink, lineWidth: 1)
                )
        }
    }

    private func runScene(_ scene: HCScene) {
        guard runningSceneID == nil else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        runningSceneID = scene.id
        runProgress = (0, scene.actions.count)
        Task {
            let result = await SceneRunner(registry: registry).run(scene)
            await MainActor.run {
                completeRun(scene: scene, result: result)
            }
        }
    }

    private func completeRun(scene: HCScene, result: SceneRunResult) {
        let succeeded = result.succeeded
        let total = result.total
        let isFullSuccess = result.isFullSuccess
        runningSceneID = nil
        runProgress = (succeeded, total)
        doneSceneID = scene.id
        ringSceneID = scene.id
        ringScale = 0.3
        ringOpacity = 0.25

        #if canImport(UIKit)
        if isFullSuccess {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif

        // Animate ring expansion / fade
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) {
            ringScale = 1.4
            ringOpacity = 0
        }

        // Clear ring after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if ringSceneID == scene.id { ringSceneID = nil }
        }

        // Clear DONE state after 1s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if doneSceneID == scene.id {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    doneSceneID = nil
                }
            }
        }

        if !isFullSuccess {
            // Total failure (0 succeeded out of N) gets a distinct
            // message — "can't run at all" reads different from a
            // partial. Warning haptic already fired above.
            if succeeded == 0 && total > 0 {
                toast = .error("Couldn't run \(scene.name)")
            } else {
                toast = .error("\(scene.name): \(succeeded)/\(total)")
            }
            // Present the per-device detail sheet automatically so the
            // user can see which devices failed and retry just those.
            // Only when there's at least one action — an empty scene
            // (total == 0) has nothing to show.
            if total > 0 {
                pendingResult = PendingResult(scene: scene, result: result)
            }
        }
    }
}

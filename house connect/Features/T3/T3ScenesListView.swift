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

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Home", onBack: { dismiss() })
                    TTitle(title: "Scenes.", subtitle: "\(sceneStore.scenes.count) scenes configured")

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
        .sheet(isPresented: $showCreateSceneSheet) {
            T3SceneEditorView()
        }
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
                completeRun(scene: scene, succeeded: result.succeeded, total: result.total, isFullSuccess: result.isFullSuccess)
            }
        }
    }

    private func completeRun(scene: HCScene, succeeded: Int, total: Int, isFullSuccess: Bool) {
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
            toast = .error("\(scene.name): \(succeeded)/\(total)")
        }
    }
}

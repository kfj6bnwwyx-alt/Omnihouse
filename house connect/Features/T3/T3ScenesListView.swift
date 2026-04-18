//
//  T3ScenesListView.swift
//  house connect
//
//  T3/Swiss scenes list — indexed scene rows with run buttons.
//

import SwiftUI

struct T3ScenesListView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(SceneStore.self) private var sceneStore
    @Environment(\.dismiss) private var dismiss

    @State private var runningSceneID: UUID?
    @State private var toast: Toast?

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

                            Image(systemName: scene.iconSystemName)
                                .font(T3.inter(18, weight: .medium))
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
                                if runningSceneID == scene.id {
                                    ProgressView()
                                        .frame(width: 40, height: 28)
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
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) {
                            if i == sceneStore.scenes.count - 1 { TRule() }
                        }
                    }

                    // Add scene dashed button
                    Button { } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(T3.inter(14, weight: .medium))
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
    }

    private func runScene(_ scene: HCScene) {
        guard runningSceneID == nil else { return }
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

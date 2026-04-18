//
//  T3CreateSceneSheet.swift
//  house connect
//
//  Presented from T3ScenesListView's "Add scene" button. Creates a new
//  empty HCScene via SceneStore.add. Actions are left empty — the user
//  fills them in later via SceneEditorView (which is the existing
//  orphan/undesigned editor). This keeps the creation flow honest:
//  we can name + iconify a scene here, but composition lives elsewhere.
//

import SwiftUI

struct T3CreateSceneSheet: View {
    @Environment(SceneStore.self) private var sceneStore
    @Environment(\.dismiss) private var dismiss

    @State private var sceneName: String = ""
    @State private var selectedIcon: String = "sparkles"
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    /// SF Symbol pool mirroring the seeded defaults + a few extras.
    private static let iconChoices: [(sf: String, label: String)] = [
        ("sparkles", "SCENE"),
        ("sun.max.fill", "MORNING"),
        ("moon.fill", "SLEEP"),
        ("tv.fill", "MOVIE"),
        ("shield.fill", "AWAY"),
        ("house.fill", "HOME"),
        ("fork.knife", "DINNER"),
        ("book.fill", "READING"),
    ]

    private var canCreate: Bool {
        !sceneName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TTitle(title: "New scene.", subtitle: "Actions can be added after creation")

                    // Name
                    TSectionHead(title: "Name", count: "")
                    VStack(alignment: .leading, spacing: 10) {
                        TLabel(text: "SCENE NAME")
                        TextField("Movie Night", text: $sceneName)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .font(T3.inter(22, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .submitLabel(.done)
                            .onSubmit { focused = false }
                        Rectangle()
                            .fill(focused ? T3.accent : T3.rule)
                            .frame(height: focused ? 1.5 : 1)
                            .animation(.easeOut(duration: 0.18), value: focused)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }

                    // Icon
                    TSectionHead(title: "Icon", count: String(format: "%02d", Self.iconChoices.count))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.iconChoices, id: \.sf) { choice in
                                Button {
                                    selectedIcon = choice.sf
                                } label: {
                                    VStack(spacing: 6) {
                                        T3IconImage(systemName: choice.sf)
                                            .frame(width: 22, height: 22)
                                            .foregroundStyle(selectedIcon == choice.sf ? T3.page : T3.ink)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == choice.sf ? T3.ink : T3.panel)
                                            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                                        Text(choice.label)
                                            .font(T3.mono(9))
                                            .tracking(1.4)
                                            .foregroundStyle(selectedIcon == choice.sf ? T3.ink : T3.sub)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(choice.label)
                                .accessibilityAddTraits(selectedIcon == choice.sf ? [.isSelected, .isButton] : .isButton)
                            }
                        }
                        .padding(.horizontal, T3.screenPadding)
                    }
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(T3.mono(11))
                            .tracking(0.8)
                            .foregroundStyle(T3.danger)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.top, 16)
                    }

                    // Action
                    Button {
                        createScene()
                    } label: {
                        Text("CREATE SCENE")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.page)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canCreate ? T3.ink : T3.ink.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                    .accessibilityLabel("Create scene")
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 24)

                    Spacer(minLength: 120)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .background(T3.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationBackground(T3.page)
    }

    private func createScene() {
        let trimmed = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let scene = HCScene(name: trimmed, iconSystemName: selectedIcon)
        sceneStore.add(scene)
        dismiss()
    }
}

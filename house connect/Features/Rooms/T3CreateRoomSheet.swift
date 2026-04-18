//
//  T3CreateRoomSheet.swift
//  house connect
//
//  T3/Swiss "create a new room" sheet. Replaces the legacy
//  CreateRoomSheet 2026-04-18. Presented from T3RoomsTabView.
//

import SwiftUI

struct T3CreateRoomSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var roomName: String = ""
    @State private var selectedIcon: String = "sofa.fill"
    @State private var selectedHomeID: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    /// SF Symbol pool for the icon picker. Purely visual for now — the
    /// legacy CreateRoomSheet didn't persist an icon, so we don't either.
    /// Task 7 sweeps these into T3Icon.map.
    private static let iconChoices: [(sf: String, label: String)] = [
        ("sofa.fill", "LIVING"),
        ("bed.double.fill", "BEDROOM"),
        ("fork.knife", "KITCHEN"),
        ("shower.fill", "BATH"),
        ("desktopcomputer", "OFFICE"),
        ("car.fill", "GARAGE"),
        ("leaf.fill", "OUTDOOR"),
        ("square.grid.2x2.fill", "OTHER"),
    ]

    private var availableHomes: [Home] {
        registry.allHomes.sorted {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var canCreate: Bool {
        !roomName.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedHomeID != nil
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TTitle(title: "New room.", subtitle: "Appears on Home + Rooms tabs")

                    // Name
                    TSectionHead(title: "Name", count: "")
                    VStack(alignment: .leading, spacing: 10) {
                        TLabel(text: "ROOM NAME")
                        TextField("Living Room", text: $roomName)
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

                    // Home selector (only if >1 home available)
                    if availableHomes.count > 1 {
                        TSectionHead(title: "Home", count: String(format: "%02d", availableHomes.count))
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(availableHomes, id: \.id) { home in
                                Button {
                                    selectedHomeID = home.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(home.name)
                                                .font(T3.inter(15, weight: .medium))
                                                .foregroundStyle(T3.ink)
                                            Text(home.provider.displayLabel.uppercased())
                                                .font(T3.mono(10))
                                                .tracking(1.2)
                                                .foregroundStyle(T3.sub)
                                        }
                                        Spacer()
                                        if selectedHomeID == home.id {
                                            T3IconImage(systemName: "checkmark")
                                                .frame(width: 14, height: 14)
                                                .foregroundStyle(T3.ink)
                                        }
                                    }
                                    .padding(.horizontal, T3.screenPadding)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .bottom) { TRule() }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedHomeID == home.id ? [.isSelected, .isButton] : .isButton)
                            }
                        }
                        .overlay(alignment: .top) { TRule() }
                    }

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
                        Task { await createRoom() }
                    } label: {
                        Text(isSaving ? "CREATING…" : "CREATE ROOM")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.page)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canCreate ? T3.ink : T3.ink.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                    .accessibilityLabel("Create room")
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 24)

                    Spacer(minLength: 120)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .interactiveDismissDisabled(isSaving)
            .background(T3.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .onAppear {
                focused = true
                if selectedHomeID == nil {
                    selectedHomeID = availableHomes.first?.id
                }
            }
        }
    }

    private func createRoom() async {
        guard let homeID = selectedHomeID else { return }
        let trimmed = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await registry.createRoom(named: trimmed, inHomeWithID: homeID)
            dismiss()
        } catch {
            if error is CancellationError { return }
            errorMessage = "Could not create room: \(error.localizedDescription)"
        }
    }
}

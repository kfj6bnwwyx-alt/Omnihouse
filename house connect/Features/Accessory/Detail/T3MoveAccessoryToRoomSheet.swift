//
//  T3MoveAccessoryToRoomSheet.swift
//  house connect
//
//  Sheet that lets the user move a device between rooms within
//  its OWN provider. (Cross-provider moves aren't a thing —
//  `assignAccessory` is per-provider, and a device fundamentally
//  belongs to the ecosystem that enrolled it.) Opens from
//  `T3DeviceManagementSection`'s "Move to room" row; that row is
//  only visible when `ProviderRegistry.supports(.moveAccessoryToRoom, on:)`
//  returns true.
//
//  Visual idiom mirrors `T3LinkRoomPickerSheet`: scrollable list,
//  hairline dividers, orange checkmark on the selected row, mono
//  caption for the current room. Rooms sort alphabetically with
//  the currently-assigned room floated to the top and tagged
//  "CURRENT" so the user has a clear "where am I now" anchor.
//

import SwiftUI

struct T3MoveAccessoryToRoomSheet: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRoomID: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var currentRoomID: String? {
        accessory?.roomID
    }

    /// Rooms from the same provider, alphabetically, with the
    /// current room (if any) floated to the top.
    private var rooms: [Room] {
        let providerRooms = registry.allRooms
            .filter { $0.provider == accessoryID.provider }
        let sorted = providerRooms.sorted { $0.name < $1.name }
        if let currentRoomID,
           let current = sorted.first(where: { $0.id == currentRoomID }) {
            return [current] + sorted.filter { $0.id != currentRoomID }
        }
        return sorted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                T3.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TTitle(
                            title: "Move to room.",
                            subtitle: "\(accessoryID.provider.displayLabel.uppercased())  ·  \(accessory?.name.uppercased() ?? "")"
                        )
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                        if rooms.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                                row(room: room, isLast: i == rooms.count - 1)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(T3.mono(11))
                                .tracking(0.6)
                                .foregroundStyle(T3.danger)
                                .padding(.horizontal, T3.screenPadding)
                                .padding(.top, 14)
                        }

                        Spacer(minLength: 120)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Move") {
                        Task { await commit() }
                    }
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(canSave ? T3.accent : T3.sub)
                    .disabled(!canSave)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .modifier(T3SheetChromeModifier())
        .onAppear {
            // Pre-select the current room so the "Move" button
            // starts disabled; selection triggers it.
            selectedRoomID = currentRoomID
        }
    }

    // MARK: - Row

    private func row(room: Room, isLast: Bool) -> some View {
        let isCurrent = room.id == currentRoomID
        let isSelected = room.id == selectedRoomID
        return Button {
            selectedRoomID = room.id
        } label: {
            HStack(spacing: 14) {
                T3IconImage(systemName: "square.grid.2x2")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    if isCurrent {
                        Text("CURRENT")
                            .font(T3.mono(9))
                            .tracking(1.4)
                            .foregroundStyle(T3.sub)
                    }
                }
                Spacer()
                if isSelected {
                    T3IconImage(systemName: "checkmark")
                        .frame(width: 14, height: 14)
                        .foregroundStyle(T3.accent)
                }
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.t3Row)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No rooms available")
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Text("\(accessoryID.provider.displayLabel) doesn't currently report any rooms. Create one in its native app first, or use Settings → Rooms to add a new room to a provider that supports it.")
                .font(T3.inter(12, weight: .regular))
                .foregroundStyle(T3.sub)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
    }

    // MARK: - Save

    private var canSave: Bool {
        guard let picked = selectedRoomID, !isSaving else { return false }
        return picked != currentRoomID
    }

    private func commit() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await registry.assignAccessory(accessoryID, toRoomID: selectedRoomID)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}

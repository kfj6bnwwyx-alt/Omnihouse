//
//  T3DeviceManagementSection.swift
//  house connect
//
//  "Device" section mounted at the bottom of every T3 detail view.
//  Replaces the older `RemoveDeviceSection` — now a three-row hub
//  for the full lifecycle of a device:
//
//    1. Rename          (opens T3RenameAccessorySheet)
//    2. Move to room    (opens T3MoveAccessoryToRoomSheet — added
//                        in the next commit)
//    3. Remove          (existing confirmationDialog flow)
//
//  Each row is hidden when the accessory's provider doesn't
//  advertise the capability via
//  `ProviderRegistry.supports(_:on:)`. That keeps Sonos / Nest
//  screens from showing rows that would throw on tap — the UX
//  we want is "operation not offered" rather than "operation
//  offered then rejected."
//
//  Back-compat: a typealias named `RemoveDeviceSection` still
//  maps to this view so any detail view that hasn't been
//  updated yet keeps compiling. New code should use
//  `T3DeviceManagementSection`.
//

import SwiftUI

struct T3DeviceManagementSection: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var showingRename = false
    @State private var showingMove = false
    @State private var isRemoving = false
    @State private var showRemoveConfirmation = false
    @State private var errorMessage: String?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var canRename: Bool {
        registry.supports(.renameAccessory, on: accessoryID)
    }

    private var canMove: Bool {
        registry.supports(.moveAccessoryToRoom, on: accessoryID)
    }

    private var canRemove: Bool {
        registry.supports(.removeAccessory, on: accessoryID)
    }

    /// True when at least one row will render. Detail views that
    /// want to skip the surrounding `TSectionHead("Device")` when
    /// nothing would appear can branch on this.
    var hasAnyAction: Bool { canRename || canMove || canRemove }

    var body: some View {
        if hasAnyAction {
            VStack(spacing: 0) {
                if canRename {
                    actionRow(
                        label: "Rename device",
                        icon: "square.and.pencil",
                        tint: T3.ink,
                        isFirst: true,
                        isLast: !canMove && !canRemove
                    ) {
                        showingRename = true
                    }
                }

                if canMove {
                    actionRow(
                        label: "Move to room",
                        icon: "square.grid.2x2",
                        tint: T3.ink,
                        isFirst: !canRename,
                        isLast: !canRemove
                    ) {
                        showingMove = true
                    }
                }

                if canRemove {
                    actionRow(
                        label: isRemoving ? "Removing…" : "Remove device",
                        icon: "trash",
                        tint: T3.danger,
                        isFirst: !canRename && !canMove,
                        isLast: true,
                        role: .destructive,
                        loading: isRemoving
                    ) {
                        showRemoveConfirmation = true
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(T3.inter(12, weight: .regular))
                        .foregroundStyle(T3.danger)
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .confirmationDialog(
                "Remove \(accessory?.name ?? "this device")?",
                isPresented: $showRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    Task { await performRemove() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will unpair the device from \(accessory?.id.provider.displayLabel ?? "its ecosystem"). You can re-add it later from the Add tab.")
            }
            .sheet(isPresented: $showingRename) {
                T3RenameAccessorySheet(accessoryID: accessoryID)
                    .environment(registry)
            }
            .sheet(isPresented: $showingMove) {
                // Populated in the next commit. Until then tapping
                // "Move to room" opens the placeholder — the
                // capability flag flips to true only when the real
                // sheet lands.
                EmptyMoveSheetPlaceholder()
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func actionRow(
        label: String,
        icon: String,
        tint: Color,
        isFirst: Bool,
        isLast: Bool,
        role: ButtonRole? = nil,
        loading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                if loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(T3.inter(14, weight: .medium))
                Spacer()
                T3IconImage(systemName: icon)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.t3Row)
        .disabled(loading)
        .overlay(alignment: .top) { if isFirst { TRule() } }
        .overlay(alignment: .bottom) { TRule() }
    }

    private func performRemove() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await registry.removeAccessory(accessoryID)
            dismiss()
        } catch {
            errorMessage = "Could not remove: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
        }
    }
}

// MARK: - Placeholder for Move-to-Room sheet

/// Stand-in until `T3MoveAccessoryToRoomSheet` lands in the next
/// commit. Kept minimal so the build stays green. Because every
/// capability-matrix entry for `.moveAccessoryToRoom` is currently
/// `false`, this sheet is never actually presented in v1 — the
/// placeholder exists only so the `if canMove { ... }` branch
/// compiles.
private struct EmptyMoveSheetPlaceholder: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Move to room — coming soon.")
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Button("Close") { dismiss() }
                .font(T3.inter(14, weight: .medium))
                .foregroundStyle(T3.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T3.page)
    }
}

// MARK: - Back-compat typealias

/// Existing detail views still reference the old `RemoveDeviceSection`
/// identifier. We rename the call sites in a single commit, but
/// keeping the typealias around means any that slip through a
/// refactor still compile cleanly until the next grep-and-replace
/// catches up.
typealias RemoveDeviceSection = T3DeviceManagementSection

//
//  RemoveDeviceSection.swift
//  house connect
//
//  Reusable "Remove Device" button + confirmation dialog used at the
//  bottom of every bespoke detail screen. Extracted so the six-plus
//  detail views don't each duplicate the same 50 lines of state
//  management and dialog plumbing.
//
//  Usage: drop `RemoveDeviceSection(accessoryID: ...)` at the bottom
//  of your detail view's VStack/ScrollView. On successful removal the
//  view dismisses itself via `@Environment(\.dismiss)`.
//

import SwiftUI

struct RemoveDeviceSection: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isRemoving = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                HStack {
                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(T3.danger)
                            .accessibilityHidden(true)
                    }
                    Text("Remove device")
                        .font(T3.inter(14, weight: .medium))
                    Spacer()
                    T3IconImage(systemName: "trash")
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(T3.danger)
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 14)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }
            }
            .buttonStyle(.plain)
            .disabled(isRemoving)
            .accessibilityLabel(isRemoving ? "Removing device" : "Remove device")
            .accessibilityHint("Permanently unpairs \(accessory?.name ?? "this device"). A confirmation will appear before removal.")
            .confirmationDialog(
                "Remove \(accessory?.name ?? "this device")?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    Task { await performRemove() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will unpair the device from \(accessory?.id.provider.displayLabel ?? "its ecosystem"). You can re-add it later from the Add tab.")
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

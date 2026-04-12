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
        VStack(spacing: 8) {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                HStack {
                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.red)
                    }
                    Text("Remove Device")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.red)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .disabled(isRemoving)
            .accessibilityLabel(isRemoving ? "Removing device" : "Remove Device")
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
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
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

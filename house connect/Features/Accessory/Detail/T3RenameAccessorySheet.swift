//
//  T3RenameAccessorySheet.swift
//  house connect
//
//  Sheet for renaming a device. Mirrors the inline rename editor in
//  `T3RoomDetailView.swift:193-280` — focus state, animated
//  underline, inline error, loading state — but lives in its own
//  sheet so a device detail view can mount it without restructuring
//  the whole screen.
//
//  Visible only when the provider advertises `.renameAccessory` via
//  `ProviderRegistry.supports(_:on:)`; on unsupported providers
//  (Sonos, Nest) the `T3DeviceManagementSection` hides the row
//  that would open this sheet, so we never attempt an impossible
//  rename.
//

import SwiftUI

struct T3RenameAccessorySheet: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    @State private var draft: String = ""
    @State private var isRenaming = false
    @State private var errorMessage: String?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                T3.page.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    TTitle(
                        title: "Rename.",
                        subtitle: accessoryID.provider.displayLabel.uppercased()
                    )
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)

                    VStack(alignment: .leading, spacing: 10) {
                        TLabel(text: "DEVICE NAME")

                        TextField(accessory?.name ?? "Name", text: $draft)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .font(T3.inter(22, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .submitLabel(.done)
                            .onSubmit { Task { await commit() } }

                        Rectangle()
                            .fill(focused ? T3.accent : T3.rule)
                            .frame(height: focused ? 1.5 : 1)
                            .animation(.easeOut(duration: 0.18), value: focused)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(T3.mono(11))
                                .tracking(0.6)
                                .foregroundStyle(T3.danger)
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 28)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRenaming ? "Saving…" : "Save") {
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
            draft = accessory?.name ?? ""
            focused = true
        }
    }

    // MARK: - Actions

    private var canSave: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRenaming else { return false }
        return trimmed != accessory?.name
    }

    private func commit() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != accessory?.name else {
            dismiss()
            return
        }

        isRenaming = true
        errorMessage = nil
        defer { isRenaming = false }

        do {
            try await registry.rename(accessoryID: accessoryID, to: trimmed)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}

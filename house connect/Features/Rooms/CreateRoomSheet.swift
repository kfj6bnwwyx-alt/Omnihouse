//
//  CreateRoomSheet.swift
//  house connect
//
//  Modal for creating a new room. User picks which home it belongs to (one
//  per provider is typical; HomeKit users sometimes have multiple homes)
//  and types a name. Hits Save → we call the right provider via the
//  registry's fan-out method.
//

import SwiftUI

struct CreateRoomSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedHomeID: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var availableHomes: [Home] {
        registry.allHomes.sorted {
            // Primary home first, then alphabetical within each provider.
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedHomeID != nil
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home") {
                    if availableHomes.isEmpty {
                        Text("No homes available. Connect a provider first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Home", selection: $selectedHomeID) {
                            ForEach(availableHomes, id: \.id) { home in
                                HStack {
                                    Text(home.name)
                                    Text("·")
                                        .accessibilityHidden(true)
                                    Text(home.provider.displayLabel)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(home.name), \(home.provider.displayLabel)")
                                .tag(Optional(home.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        .accessibilityLabel("Select home")
                        .accessibilityHint("Choose which home to create the room in")
                    }
                }

                Section("Name") {
                    TextField("Room name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityLabel("Room name")
                        .accessibilityHint("Enter a name for the new room")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                        .accessibilityHint("Dismisses without creating a room")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .accessibilityLabel("Save")
                    .accessibilityHint("Creates the new room")
                }
            }
            .onAppear {
                // Default to the first available home so the user just
                // has to type a name in the common single-home case.
                if selectedHomeID == nil {
                    selectedHomeID = availableHomes.first?.id
                }
            }
        }
    }

    private func save() async {
        guard let homeID = selectedHomeID else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await registry.createRoom(named: trimmed, inHomeWithID: homeID)
            dismiss()
        } catch {
            errorMessage = "Could not create room: \(error)"
        }
    }
}

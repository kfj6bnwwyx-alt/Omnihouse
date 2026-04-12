//
//  SmartThingsTokenEntryView.swift
//  house connect
//
//  Presented as a sheet from SettingsView. Collects a SmartThings Personal
//  Access Token via SecureField, stores it in Keychain, then kicks off a
//  provider refresh so the dashboard fills in.
//
//  Design choices:
//    - SecureField — obvious, but worth noting: this is the only place in
//      the app the token is ever typed. It never touches UserDefaults, never
//      leaves the device, and is handed straight to KeychainTokenStore.
//    - We don't "validate" the token by parsing it — SmartThings PATs aren't
//      a fixed format. Instead we save it and immediately trigger a refresh;
//      if the refresh reports an auth error, we show it and let the user fix
//      the token.
//

import SwiftUI

struct SmartThingsTokenEntryView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var token: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var smartThingsProvider: SmartThingsProvider? {
        registry.provider(for: .smartThings) as? SmartThingsProvider
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Personal Access Token", text: $token)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("SmartThings Personal Access Token")
                        .accessibilityHint("Enter your personal access token from the SmartThings developer portal")
                } header: {
                    Text("Access token")
                } footer: {
                    Text("Create at account.smartthings.com → Personal Access Tokens. Required scopes: Devices (read/write), Locations (read), Rooms (read). The token is stored in the iOS Keychain on this device only.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }

                Section {
                    Link(destination: URL(string: "https://account.smartthings.com/tokens")!) {
                        Label("Open SmartThings tokens page", systemImage: "safari")
                    }
                    .accessibilityHint("Opens the SmartThings website in Safari to create a personal access token")
                }
            }
            .navigationTitle("Connect SmartThings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Dismiss without saving the token")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .accessibilityLabel("Save token")
                    .accessibilityHint("Save the access token and connect to SmartThings")
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Connecting…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Connecting to SmartThings")
                }
            }
        }
    }

    // MARK: - Actions

    private func save() async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let provider = smartThingsProvider else { return }

        isSaving = true
        defer { isSaving = false }

        let store = KeychainTokenStore()
        do {
            try store.set(trimmed, for: .smartThingsPAT)
        } catch {
            errorMessage = "Couldn't save to Keychain: \(error.localizedDescription)"
            return
        }

        await provider.refresh()

        if provider.authorizationState == .authorized {
            // Clear the token from memory before dismissing.
            token = ""
            dismiss()
        } else {
            errorMessage = provider.lastError ?? "Couldn't reach SmartThings with that token. Double-check its scopes."
            // Remove the bad token so the connect button reappears cleanly.
            try? store.delete(.smartThingsPAT)
        }
    }
}

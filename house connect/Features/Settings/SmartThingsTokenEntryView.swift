//
//  SmartThingsTokenEntryView.swift
//  house connect
//
//  SmartThings PAT entry. T3/Swiss rewrite 2026-04-18 — pushed from
//  T3ProviderDetailView. Form → ScrollView with T3 primitives. All
//  keychain + refresh semantics preserved; tokens still never touch
//  UserDefaults.
//

import SwiftUI

struct SmartThingsTokenEntryView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var token: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private var smartThingsProvider: SmartThingsProvider? {
        registry.provider(for: .smartThings) as? SmartThingsProvider
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "SmartThings.", subtitle: "Personal Access Token")

                TSectionHead(title: "Access Token", count: "")
                VStack(alignment: .leading, spacing: 10) {
                    TLabel(text: "PAT FROM SMARTTHINGS DEVELOPER PORTAL")
                    SecureField("Paste your token", text: $token)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focused)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    Rectangle()
                        .fill(focused ? T3.accent : T3.rule)
                        .frame(height: focused ? 1.5 : 1)
                        .animation(.easeOut(duration: 0.18), value: focused)

                    Text("Create at account.smartthings.com → Personal Access Tokens. Required scopes: Devices (read/write), Locations (read), Rooms (read). Token is stored in the iOS Keychain on this device only.")
                        .font(T3.inter(12, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(3)
                        .padding(.top, 4)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 14)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }

                if let errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(T3.danger)
                            .frame(width: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            TLabel(text: "TOKEN REJECTED",
                                   color: T3.danger)
                            Text(errorMessage)
                                .font(T3.inter(13, weight: .regular))
                                .foregroundStyle(T3.ink)
                                .lineSpacing(3)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 14)
                }

                // External link
                TSectionHead(title: "Reference", count: "")
                if let url = URL(string: "https://account.smartthings.com/tokens") {
                    Link(destination: url) {
                        HStack(spacing: 14) {
                            T3IconImage(systemName: "arrow.up.right")
                                .frame(width: 16, height: 16)
                                .foregroundStyle(T3.ink)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Open SmartThings tokens page")
                                    .font(T3.inter(15, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                TLabel(text: "ACCOUNT.SMARTTHINGS.COM/TOKENS")
                            }
                            Spacer()
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }
                }

                // Save
                Button {
                    focused = false
                    Task { await save() }
                } label: {
                    HStack(spacing: 10) {
                        if isSaving { ProgressView().tint(T3.page).scaleEffect(0.8) }
                        Text(isSaving ? "CONNECTING…" : "SAVE TOKEN")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.page)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canSave ? T3.ink : T3.ink.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 24)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    private var canSave: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

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
            token = ""
            dismiss()
        } else {
            errorMessage = provider.lastError ?? "Couldn't reach SmartThings with that token. Double-check its scopes."
            try? store.delete(.smartThingsPAT)
        }
    }
}

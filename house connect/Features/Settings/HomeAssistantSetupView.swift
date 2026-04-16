//
//  HomeAssistantSetupView.swift
//  house connect
//
//  Setup sheet for connecting to a Home Assistant instance. Two paths:
//  1. Auto-discover HA on the local network via Bonjour
//  2. Manual URL entry
//  Then enter a long-lived access token (created in HA user profile).
//

import SwiftUI

struct HomeAssistantSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderRegistry.self) private var registry

    @State private var discovery = HomeAssistantDiscovery()
    @State private var selectedURL: String = ""
    @State private var token: String = ""
    @State private var manualURL: String = ""
    @State private var isConnecting: Bool = false
    @State private var error: String?
    @State private var showManualEntry: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                discoverySection
                tokenSection
                connectButton
            }
            .navigationTitle("Connect to Home Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                discovery.startScan()
            }
            .onDisappear {
                discovery.stopScan()
            }
        }
    }

    // MARK: - Discovery

    @ViewBuilder
    private var discoverySection: some View {
        Section {
            if discovery.isSearching && discovery.instances.isEmpty {
                HStack {
                    ProgressView()
                    Text("Scanning your network…")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(discovery.instances) { instance in
                Button {
                    selectedURL = instance.url.absoluteString
                    showManualEntry = false
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(instance.name)
                                .fontWeight(.medium)
                            Text("\(instance.url.absoluteString) — v\(instance.version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedURL == instance.url.absoluteString {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .tint(.primary)
                .accessibilityLabel("\(instance.name), version \(instance.version)")
                .accessibilityAddTraits(selectedURL == instance.url.absoluteString ? .isSelected : [])
            }

            if !discovery.isSearching && discovery.instances.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No instances found")
                        .foregroundStyle(.secondary)
                    Text("Make sure Home Assistant is running and your iPhone is on the same Wi-Fi network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showManualEntry.toggle()
                if showManualEntry { selectedURL = "" }
            } label: {
                Label(
                    showManualEntry ? "Use discovered instance" : "Enter URL manually",
                    systemImage: showManualEntry ? "antenna.radiowaves.left.and.right" : "keyboard"
                )
            }

            if showManualEntry {
                TextField("http://192.168.1.100:8123", text: $manualURL)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: manualURL) { _, newValue in
                        selectedURL = newValue
                    }
            }
        } header: {
            Text("Home Assistant Server")
        } footer: {
            Text("Select a discovered instance or enter the URL manually.")
        }
    }

    // MARK: - Token

    private var tokenSection: some View {
        Section {
            SecureField("Long-lived access token", text: $token)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Access Token")
        } footer: {
            Text("Create a long-lived access token in Home Assistant: Profile → Security → Long-Lived Access Tokens → Create Token.")
        }
    }

    // MARK: - Connect

    @ViewBuilder
    private var connectButton: some View {
        Section {
            Button {
                Task { await connect() }
            } label: {
                HStack {
                    Spacer()
                    if isConnecting {
                        ProgressView()
                        Text("Connecting…")
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(selectedURL.isEmpty || token.isEmpty || isConnecting)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func connect() async {
        isConnecting = true
        error = nil

        // Normalize URL
        var urlString = selectedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http") {
            urlString = "http://\(urlString)"
        }
        // Remove trailing slash
        if urlString.hasSuffix("/") {
            urlString = String(urlString.dropLast())
        }

        guard let url = URL(string: urlString) else {
            error = "Invalid URL."
            isConnecting = false
            return
        }

        // Test the connection
        let testClient = HomeAssistantRESTClient(baseURL: url, token: token)
        let reachable = await testClient.checkConnection()

        guard reachable else {
            error = "Can't reach Home Assistant at \(urlString). Check the URL and make sure you're on the same network."
            isConnecting = false
            return
        }

        // Verify the token works by fetching config
        do {
            _ = try await testClient.getConfig()
            // Token works — save credentials
            let tokenStore = KeychainTokenStore()
            try tokenStore.set(token, for: .homeAssistantToken)
            try tokenStore.set(urlString, for: .homeAssistantURL)

            // Start the provider
            if let provider = registry.provider(for: .homeAssistant) as? HomeAssistantProvider {
                await provider.start()
            }

            dismiss()
        } catch {
            self.error = "Connected to server but token was rejected. Make sure you copied the full token."
            isConnecting = false
        }
    }
}

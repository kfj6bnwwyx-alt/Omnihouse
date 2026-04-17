//
//  HomeAssistantSetupView.swift
//  house connect
//
//  Setup sheet for connecting to a Home Assistant instance.
//  Auto-discovers HA on the local network and defaults to the first
//  found instance. A segmented control lets the user switch between
//  discovered and manual URL entry.
//

import SwiftUI

struct HomeAssistantSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderRegistry.self) private var registry

    @State private var discovery = HomeAssistantDiscovery()
    @State private var token: String = ""
    /// Pre-filled with the known HA address. The user can edit it.
    @State private var manualURL: String = "http://192.168.4.23:8123"
    @State private var remoteURL: String = "http://100.67.208.9:8123"
    @State private var isConnecting: Bool = false
    @State private var error: String?
    @State private var connectionMode: ConnectionMode = .discovered

    enum ConnectionMode: String, CaseIterable {
        case discovered = "Discovered"
        case manual = "Manual URL"
    }

    /// The effective URL based on the current mode.
    private var effectiveURL: String {
        switch connectionMode {
        case .discovered:
            return discovery.instances.first?.url.absoluteString ?? ""
        case .manual:
            return manualURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                remoteSection
                tokenSection
                connectSection
            }
            .navigationTitle("Home Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                discovery.startScan()
                let store = KeychainTokenStore()
                // Pre-fill URLs from Keychain if available
                if let savedURL = store.token(for: .homeAssistantURL), !savedURL.isEmpty {
                    manualURL = savedURL
                }
                if let savedRemote = store.token(for: .homeAssistantRemoteURL), !savedRemote.isEmpty {
                    remoteURL = savedRemote
                }
                // Default to manual mode since discovery is unreliable
                if discovery.instances.isEmpty {
                    connectionMode = .manual
                }
            }
            .onDisappear {
                discovery.stopScan()
            }
        }
    }

    // MARK: - Server Section

    private var serverSection: some View {
        Section {
            // Segmented control: Discovered vs Manual
            Picker("Connection", selection: $connectionMode) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            switch connectionMode {
            case .discovered:
                discoveredContent
            case .manual:
                manualContent
            }
        } header: {
            Text("Server")
        }
        .onChange(of: connectionMode) { _, mode in
            if mode == .manual, manualURL.isEmpty,
               let first = discovery.instances.first {
                manualURL = first.url.absoluteString
            }
        }
    }

    // MARK: - Discovered mode

    @ViewBuilder
    private var discoveredContent: some View {
        if discovery.isSearching && discovery.instances.isEmpty {
            HStack(spacing: 12) {
                ProgressView()
                Text("Scanning your network…")
                    .foregroundStyle(.secondary)
            }
        } else if let instance = discovery.instances.first {
            // Auto-selected — show the found instance with a green badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(instance.name)
                            .fontWeight(.semibold)
                    }
                    Text(instance.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Version \(instance.version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(instance.name) found at \(instance.url.absoluteString)")

            // If multiple found, show count
            if discovery.instances.count > 1 {
                Text("\(discovery.instances.count) instances found — using first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("No instances found")
                    .fontWeight(.medium)
                Text("Make sure Home Assistant is running and your phone is on the same Wi-Fi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                discovery.startScan()
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Manual mode

    private var manualContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("http://192.168.1.100:8123", text: $manualURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Home Assistant server URL")
        }
    }

    // MARK: - Remote URL (Tailscale)

    private var remoteSection: some View {
        Section {
            TextField("http://100.x.x.x:8123", text: $remoteURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Remote URL (Tailscale)")
        } header: {
            Text("Remote Access (Optional)")
        } footer: {
            Text("Tailscale or external URL for when you're away from home. The app tries the local URL first, then falls back to this one.")
        }
    }

    // MARK: - Token Section

    private var tokenSection: some View {
        Section {
            SecureField("Paste your long-lived access token", text: $token)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Long-lived access token")
        } header: {
            Text("Access Token")
        } footer: {
            Text("In Home Assistant: Profile → Security → Long-Lived Access Tokens → Create Token. Copy the full token and paste here.")
        }
    }

    // MARK: - Connect Section

    private var connectSection: some View {
        Section {
            Button {
                Task { await connect() }
            } label: {
                HStack {
                    Spacer()
                    if isConnecting {
                        ProgressView()
                            .padding(.trailing, 4)
                        Text("Connecting…")
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(effectiveURL.isEmpty || token.isEmpty || isConnecting)

            if let error {
                Label {
                    Text(error)
                        .font(.caption)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .foregroundStyle(.red)
            }

        }
    }

    // MARK: - Connect logic

    private func connect() async {
        isConnecting = true
        error = nil

        // Normalize URL
        var urlString = effectiveURL
        if !urlString.hasPrefix("http") {
            urlString = "http://\(urlString)"
        }
        if urlString.hasSuffix("/") {
            urlString = String(urlString.dropLast())
        }

        guard let url = URL(string: urlString) else {
            error = "Invalid URL: \(urlString)"
            isConnecting = false
            return
        }

        // Step 1: Check basic reachability
        let testClient = HomeAssistantRESTClient(baseURL: url, token: token)
        let reachable = await testClient.checkConnection()

        guard reachable else {
            // Try to give a more helpful error
            error = "Can't reach Home Assistant at \(urlString). "
                + "Check: (1) your phone is on the same Wi-Fi, "
                + "(2) HA is running, "
                + "(3) the URL is correct."
            isConnecting = false
            return
        }

        // Step 2: Verify token by fetching config
        do {
            let config = try await testClient.getConfig()

            // Save credentials to Keychain
            let tokenStore = KeychainTokenStore()
            try tokenStore.set(token, for: .homeAssistantToken)
            try tokenStore.set(urlString, for: .homeAssistantURL)

            // Save remote/Tailscale URL if provided
            let trimmedRemote = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedRemote.isEmpty {
                var remote = trimmedRemote
                if !remote.hasPrefix("http") { remote = "http://\(remote)" }
                if remote.hasSuffix("/") { remote = String(remote.dropLast()) }
                try tokenStore.set(remote, for: .homeAssistantRemoteURL)
            }

            // Start the provider — it will try local first, then remote
            if let provider = registry.provider(for: .homeAssistant) as? HomeAssistantProvider {
                await provider.start()
            }

            dismiss()
        } catch {
            self.error = "Server reached but authentication failed. "
                + "Make sure you copied the FULL token (it's very long). "
                + "Error: \(error.localizedDescription)"
            isConnecting = false
        }
    }
}

//
//  HomeAssistantSetupView.swift
//  house connect
//
//  Home Assistant setup. T3/Swiss rewrite 2026-04-18 — pushed from
//  T3ProviderDetailView as a regular navigation destination, so the
//  outer NavigationStack + toolbar are dropped. Form → ScrollView.
//  All discovery, keychain, and connect logic preserved.
//

import SwiftUI

struct HomeAssistantSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderRegistry.self) private var registry

    @State private var discovery = HomeAssistantDiscovery()
    @State private var token: String = ""
    @State private var manualURL: String = "http://192.168.4.23:8123"
    @State private var remoteURL: String = "http://100.67.208.9:8123"
    @State private var isConnecting: Bool = false
    @State private var error: String?
    @State private var connectionMode: ConnectionMode = .manual

    @FocusState private var focusedField: Field?

    enum ConnectionMode: String, CaseIterable {
        case discovered = "DISCOVERED"
        case manual = "MANUAL"
    }

    enum Field: Hashable {
        case url, remoteURL, token
    }

    private var effectiveURL: String {
        switch connectionMode {
        case .discovered:
            return discovery.instances.first?.url.absoluteString ?? ""
        case .manual:
            return manualURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Home Assistant.", subtitle: "URL · token · Tailscale fallback")

                modeSection
                serverSection
                remoteSection
                tokenSection
                connectSection

                if let error {
                    errorBlock(error)
                }

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .onAppear {
            discovery.startScan()
            let store = KeychainTokenStore()
            if let savedURL = store.token(for: .homeAssistantURL), !savedURL.isEmpty {
                manualURL = savedURL
            }
            if let savedRemote = store.token(for: .homeAssistantRemoteURL), !savedRemote.isEmpty {
                remoteURL = savedRemote
            }
        }
        .onDisappear {
            discovery.stopScan()
        }
        .onChange(of: connectionMode) { _, mode in
            if mode == .manual, manualURL.isEmpty,
               let first = discovery.instances.first {
                manualURL = first.url.absoluteString
            }
        }
    }

    // MARK: - Mode segmented

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Mode", count: "")
            HStack(spacing: 8) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    Button {
                        connectionMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(T3.mono(11))
                            .tracking(2)
                            .foregroundStyle(connectionMode == mode ? T3.page : T3.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(connectionMode == mode ? T3.ink : T3.panel)
                            .overlay(Rectangle().stroke(T3.ink, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TSectionHead(title: "Server", count: "")

            switch connectionMode {
            case .discovered:
                discoveredContent
            case .manual:
                manualContent
            }
        }
    }

    @ViewBuilder
    private var discoveredContent: some View {
        let padded = VStack(alignment: .leading, spacing: 8) {
            if discovery.isSearching && discovery.instances.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.8).tint(T3.ink)
                    Text("Scanning local network…")
                        .font(T3.inter(14, weight: .regular))
                        .foregroundStyle(T3.sub)
                }
            } else if let instance = discovery.instances.first {
                HStack(alignment: .top, spacing: 10) {
                    TDot(size: 8, color: Color(red: 0.29, green: 0.56, blue: 0.36))
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(instance.name)
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                        Text(instance.url.absoluteString)
                            .font(T3.mono(11))
                            .foregroundStyle(T3.sub)
                        TLabel(text: "VERSION \(instance.version)")
                    }
                    Spacer()
                }
                if discovery.instances.count > 1 {
                    TLabel(text: "\(discovery.instances.count) INSTANCES · USING FIRST")
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No instances found")
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    Text("Make sure Home Assistant is running and your phone is on the same Wi-Fi.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(2)
                    Button {
                        discovery.startScan()
                    } label: {
                        HStack(spacing: 8) {
                            T3IconImage(systemName: "arrow.clockwise")
                                .frame(width: 12, height: 12)
                                .foregroundStyle(T3.accent)
                            Text("SCAN AGAIN")
                                .font(T3.mono(11))
                                .tracking(2)
                                .foregroundStyle(T3.accent)
                        }
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        padded
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
    }

    private var manualContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TLabel(text: "LOCAL URL")
            TextField("http://192.168.1.100:8123", text: $manualURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .url)
                .font(T3.inter(15, weight: .medium))
                .foregroundStyle(T3.ink)
            Rectangle()
                .fill(focusedField == .url ? T3.accent : T3.rule)
                .frame(height: focusedField == .url ? 1.5 : 1)
                .animation(.easeOut(duration: 0.18), value: focusedField)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Remote (Tailscale)

    private var remoteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TSectionHead(title: "Remote", count: "OPTIONAL")

            VStack(alignment: .leading, spacing: 10) {
                TLabel(text: "TAILSCALE OR EXTERNAL URL")
                TextField("http://100.x.x.x:8123", text: $remoteURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .remoteURL)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                Rectangle()
                    .fill(focusedField == .remoteURL ? T3.accent : T3.rule)
                    .frame(height: focusedField == .remoteURL ? 1.5 : 1)
                    .animation(.easeOut(duration: 0.18), value: focusedField)

                Text("Used as fallback when the local URL isn't reachable — e.g. when you're away from home on cellular.")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
    }

    // MARK: - Token

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TSectionHead(title: "Access Token", count: "")

            VStack(alignment: .leading, spacing: 10) {
                TLabel(text: "LONG-LIVED ACCESS TOKEN")
                SecureField("Paste your token", text: $token)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .token)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                Rectangle()
                    .fill(focusedField == .token ? T3.accent : T3.rule)
                    .frame(height: focusedField == .token ? 1.5 : 1)
                    .animation(.easeOut(duration: 0.18), value: focusedField)

                Text("In Home Assistant: Profile → Security → Long-Lived Access Tokens → Create Token. Copy the FULL token (it's very long).")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
    }

    // MARK: - Connect

    private var connectSection: some View {
        VStack(spacing: 10) {
            Button {
                focusedField = nil
                Task { await connect() }
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView().tint(T3.page).scaleEffect(0.8)
                    }
                    Text(isConnecting ? "CONNECTING…" : "CONNECT")
                        .font(T3.mono(12))
                        .tracking(2)
                        .foregroundStyle(T3.page)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canConnect ? T3.ink : T3.ink.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!canConnect)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 24)
    }

    private var canConnect: Bool {
        !effectiveURL.isEmpty && !token.isEmpty && !isConnecting
    }

    private func errorBlock(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color(red: 0.77, green: 0.25, blue: 0.20))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                TLabel(text: "CONNECTION FAILED",
                       color: Color(red: 0.77, green: 0.25, blue: 0.20))
                Text(message)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.ink)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
    }

    // MARK: - Connect logic (unchanged)

    private func connect() async {
        isConnecting = true
        error = nil

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

        let testClient = HomeAssistantRESTClient(baseURL: url, token: token)
        let reachable = await testClient.checkConnection()

        guard reachable else {
            error = "Can't reach Home Assistant at \(urlString). Check: (1) your phone is on the same Wi-Fi, (2) HA is running, (3) the URL is correct."
            isConnecting = false
            return
        }

        do {
            _ = try await testClient.getConfig()

            let tokenStore = KeychainTokenStore()
            try tokenStore.set(token, for: .homeAssistantToken)
            try tokenStore.set(urlString, for: .homeAssistantURL)

            let trimmedRemote = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedRemote.isEmpty {
                var remote = trimmedRemote
                if !remote.hasPrefix("http") { remote = "http://\(remote)" }
                if remote.hasSuffix("/") { remote = String(remote.dropLast()) }
                try tokenStore.set(remote, for: .homeAssistantRemoteURL)
            }

            if let provider = registry.provider(for: .homeAssistant) as? HomeAssistantProvider {
                await provider.start()
            }

            dismiss()
        } catch {
            self.error = "Server reached but authentication failed. Make sure you copied the FULL token. \(error.localizedDescription)"
            isConnecting = false
        }
    }
}

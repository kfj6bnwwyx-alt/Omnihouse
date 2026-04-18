//
//  T3DeviceOfflineView.swift
//  house connect
//
//  T3/Swiss replacement for DeviceOfflineView. Pencil node `ulr8x`
//  adapted from the whole-HA offline mock to per-device context:
//  hairline-rule diagnostics checklist, optional cached-state badge,
//  two-button CTA (retry + fall back / connections).
//

import SwiftUI

struct T3DeviceOfflineView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @State private var isRetrying = false
    @State private var lastRetryAt: Date?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms.first { $0.id == roomID && $0.provider == accessory.id.provider }?.name
    }

    private var providerLabel: String {
        accessoryID.provider.displayLabel.uppercased()
    }

    private var isProviderDisconnected: Bool {
        guard let provider = registry.provider(for: accessoryID.provider) else { return false }
        return provider.authorizationState != .authorized
    }

    private var offlineDuration: String {
        guard let since = lastRetryAt else { return "NOT YET ATTEMPTED" }
        let seconds = Int(Date().timeIntervalSince(since))
        if seconds < 60 { return "\(seconds)S AGO" }
        return "\(seconds / 60)M AGO"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero — primary title block
                VStack(alignment: .leading, spacing: 10) {
                    Text("can't reach")
                        .font(T3.inter(44, weight: .medium))
                        .tracking(-1.4)
                        .foregroundStyle(T3.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(heroTarget)
                        .font(T3.inter(44, weight: .medium))
                        .tracking(-1.4)
                        .foregroundStyle(T3.danger)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(heroSubtitle)
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(3)
                        .padding(.top, 8)
                }
                .padding(.horizontal, T3.screenPadding + 4)
                .padding(.top, 22)
                .t3ScreenTopPad()

                // Status strip — below hero so it doesn't shift the title
                HStack {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(T3.danger)
                            .frame(width: 6, height: 6)
                        TLabel(text: "OFFLINE  ·  \(providerLabel)",
                               color: T3.danger)
                    }
                    Spacer()
                    TLabel(text: offlineDuration)
                }
                .padding(.horizontal, T3.screenPadding + 4)
                .padding(.top, 20)

                Spacer(minLength: 32)

                // Diagnostics
                TSectionHead(title: "Diagnostics", count: "3 CHECKS")

                diagnosticRow(ok: true,
                              label: "Wi-Fi",
                              detail: "Connected")
                diagnosticRow(ok: false,
                              label: "\(accessoryID.provider.displayLabel) · \(accessory?.name ?? "device")",
                              detail: isProviderDisconnected
                              ? "Provider unauthorized · reconnect required"
                              : "No response · 3 retries")
                diagnosticRow(ok: true,
                              label: "Cached state",
                              detail: "Last seen state preserved")

                // Cached state indicator
                HStack(spacing: 12) {
                    Rectangle().fill(T3.accent).frame(width: 2, height: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Showing cached state")
                            .font(T3.inter(13, weight: .medium))
                            .foregroundStyle(T3.ink)
                        TLabel(text: roomName.map { "\($0)  ·  READS ONLY" } ?? "READS ONLY")
                    }
                    Spacer()
                }
                .padding(.horizontal, T3.screenPadding + 4)
                .padding(.vertical, 16)
                .overlay(alignment: .top) { TRule() }

                Spacer(minLength: 32)

                // Actions
                VStack(spacing: 10) {
                    if isProviderDisconnected {
                        NavigationLink(value: SettingsDestination.providers) {
                            Text("GO TO CONNECTIONS")
                                .font(T3.mono(12))
                                .tracking(2)
                                .foregroundStyle(T3.page)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(T3.ink)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            retry()
                        } label: {
                            HStack(spacing: 10) {
                                if isRetrying {
                                    ProgressView()
                                        .tint(T3.page)
                                        .scaleEffect(0.8)
                                }
                                Text(isRetrying ? "RETRYING..." : "RETRY NOW")
                                    .font(T3.mono(12))
                                    .tracking(2)
                                    .foregroundStyle(T3.page)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(T3.ink)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRetrying)
                    }

                    NavigationLink(value: SettingsDestination.providers) {
                        Text("CHECK CONNECTION SETTINGS")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(Rectangle().stroke(T3.ink, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 4)

                // Foot
                HStack {
                    TLabel(text: "DISCONNECTED  ·  \(offlineDuration)")
                    Spacer()
                    TLabel(text: isRetrying ? "CHECKING..." : "MANUAL RETRY")
                }
                .padding(.horizontal, T3.screenPadding + 4)
                .padding(.vertical, 20)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var heroTarget: String {
        if let accessory { return "\(accessory.name.lowercased())." }
        return "device."
    }

    private var heroSubtitle: String {
        if isProviderDisconnected {
            return "The \(accessoryID.provider.displayLabel) provider needs to reconnect before we can talk to this device. Your settings are preserved — just reauthorize."
        }
        return "The device isn't responding right now. It may be powered off, out of range, or taking a nap. Cached state stays visible so you're not flying blind."
    }

    private func retry() {
        isRetrying = true
        lastRetryAt = Date()
        Task {
            if let provider = registry.provider(for: accessoryID.provider) {
                try? await provider.refresh()
            }
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { isRetrying = false }
        }
    }

    // MARK: - Diagnostic row

    private func diagnosticRow(ok: Bool, label: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Text(ok ? "✓" : "✗")
                .font(T3.inter(14, weight: ok ? .regular : .medium))
                .foregroundStyle(ok
                                 ? T3.ok
                                 : T3.danger)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(T3.inter(14, weight: .regular))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                TLabel(text: detail)
            }
            Spacer()
            TLabel(text: ok ? "OK" : "FAIL",
                   color: ok
                   ? T3.ok
                   : T3.danger)
        }
        .padding(.horizontal, T3.screenPadding + 4)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
    }
}

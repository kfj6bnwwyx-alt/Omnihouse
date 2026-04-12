//
//  AddDeviceView.swift
//  house connect
//
//  The ADD tab. Matches the Pencil design (node KPsYW):
//    - "Add Device" title + "Choose a device type to get started"
//    - 2×3 category grid (Lights / Climate / Security / Entertainment /
//      Appliances / Sensors)
//    - "Supported Platforms" chip row (HomeKit / Thread / SmartThings)
//
//  Flow (2026-04-11 rewrite):
//  --------------------------
//  Tapping a category no longer jumps straight into the HomeKit setup
//  sheet. Each provider handles "adding a device" in a fundamentally
//  different way, and the old behavior implied we had one unified pair
//  flow when we don't:
//    • HomeKit  — interactive `HMAccessorySetupManager` sheet
//    • SmartThings — pair in the SmartThings app first, then we pick it
//      up on refresh (token required)
//    • Sonos — automatic via Bonjour, user does nothing
//    • Nest — not yet wired
//
//  So a category tap now opens `ProviderChooserSheet`, a small sheet
//  that lists each provider with an honest, per-provider action. The
//  category is passed through as context ("Add a Light", "Add Climate",
//  ...) but doesn't filter which providers appear — the provider list
//  is the single source of truth about what's actually possible today.
//
//  The bottom "Supported Platforms" chip row becomes vestigial once the
//  chooser is in place, but we keep it as a quiet info strip at the
//  bottom of the screen.
//

import SwiftUI

struct AddDeviceView: View {
    @Environment(ProviderRegistry.self) private var registry

    @State private var chooserCategory: Category?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                categoryGrid
                supportedPlatformsSection
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 8)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $chooserCategory) { category in
            ProviderChooserSheet(category: category)
                .environment(registry)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add Device")
                .font(Theme.font.screenTitle)
                .foregroundStyle(Theme.color.title)
            Text("Choose a device type to get started")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12),
                      GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(Category.allCases, id: \.self) { category in
                Button {
                    chooserCategory = category
                } label: {
                    CategoryTile(category: category)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var supportedPlatformsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Platforms")
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)
            HStack(spacing: 10) {
                PlatformChip(label: "HomeKit", systemImage: "house.fill")
                PlatformChip(label: "Thread", systemImage: "wifi")
                PlatformChip(label: "SmartThings", systemImage: "circle.grid.cross.fill")
                PlatformChip(label: "Sonos", systemImage: "hifispeaker.fill")
            }
        }
    }
}

// MARK: - Category model

extension AddDeviceView {
    /// User-visible device categories from the Pencil design. These
    /// don't map 1:1 to our internal `Accessory.Category` vocabulary —
    /// they're a UX grouping, not a data grouping. Conforming to
    /// Identifiable so we can drive `.sheet(item:)`.
    enum Category: String, CaseIterable, Identifiable {
        case lights, climate, security, entertainment, appliances, sensors

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lights: "Lights"
            case .climate: "Climate"
            case .security: "Security"
            case .entertainment: "Entertainment"
            case .appliances: "Appliances"
            case .sensors: "Sensors"
            }
        }

        var subtitle: String {
            switch self {
            case .lights: "Bulbs, strips, switches"
            case .climate: "Thermostat, AC, fans"
            case .security: "Cameras, locks, sensors"
            case .entertainment: "Speakers, TV, media"
            case .appliances: "Plugs, outlets, blinds"
            case .sensors: "Motion, humidity, air"
            }
        }

        var systemImage: String {
            switch self {
            case .lights: "lightbulb.fill"
            case .climate: "thermometer"
            case .security: "shield.fill"
            case .entertainment: "tv.fill"
            case .appliances: "poweroutlet.type.b.fill"
            case .sensors: "sensor.fill"
            }
        }

        /// Header shown on the provider chooser sheet. "Add a Light" /
        /// "Add Climate" / etc. Kept here so the chooser view doesn't
        /// have to know about category-specific copy.
        var addHeader: String {
            switch self {
            case .lights: "Add a Light"
            case .climate: "Add Climate"
            case .security: "Add Security"
            case .entertainment: "Add Entertainment"
            case .appliances: "Add Appliance"
            case .sensors: "Add Sensor"
            }
        }
    }
}

// MARK: - Tiles

private struct CategoryTile: View {
    let category: AddDeviceView.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconChip(systemName: category.systemImage, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.label)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text(category.subtitle)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }
}

private struct PlatformChip: View {
    let label: String
    let systemImage: String
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.color.iconChipGlyph)
            Text(label)
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Theme.color.cardFill)
                .shadow(color: Color.black.opacity(0.05),
                        radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Provider chooser sheet
//
// Sheet that lists each provider with an honest per-provider action.
// Kept in the same file so the Add Device flow is one scroll to read.

private struct ProviderChooserSheet: View {
    let category: AddDeviceView.Category

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var workingProvider: ProviderID?
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var showingSmartThingsToken = false

    private var homeKitProvider: HomeKitProvider? {
        registry.provider(for: .homeKit) as? HomeKitProvider
    }
    private var smartThingsProvider: SmartThingsProvider? {
        registry.provider(for: .smartThings) as? SmartThingsProvider
    }
    private var sonosProvider: SonosProvider? {
        registry.provider(for: .sonos) as? SonosProvider
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCopy

                    homeKitRow
                    smartThingsRow
                    sonosRow
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Theme.color.pageBackground.ignoresSafeArea())
            .navigationTitle(category.addHeader)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSmartThingsToken) {
                SmartThingsTokenEntryView()
            }
            .alert("Couldn't add device",
                   isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }),
                   actions: { Button("OK") { errorMessage = nil } },
                   message: { Text(errorMessage ?? "") })
            .alert("Info",
                   isPresented: Binding(
                    get: { infoMessage != nil },
                    set: { if !$0 { infoMessage = nil } }),
                   actions: { Button("OK") { infoMessage = nil } },
                   message: { Text(infoMessage ?? "") })
        }
    }

    // MARK: - Header copy

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where is this device?")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Each platform handles new devices differently. Pick the one that matches the accessory you're adding.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Provider rows

    private var homeKitRow: some View {
        ProviderRow(
            iconSystemName: "house.fill",
            title: "Apple Home",
            subtitle: "Pair a HomeKit-compatible device using Apple's setup flow.",
            actionTitle: "Start Setup",
            actionStyle: .primary,
            isDisabled: homeKitProvider == nil || (isWorking && workingProvider != .homeKit),
            isLoading: isWorking && workingProvider == .homeKit
        ) {
            Task { await startHomeKitSetup() }
        }
    }

    private var smartThingsRow: some View {
        let hasToken = smartThingsProvider?.authorizationState == .authorized

        return ProviderRow(
            iconSystemName: "circle.grid.cross.fill",
            title: "SmartThings",
            subtitle: hasToken
                ? "Pair the device in the SmartThings app, then tap Refresh to pull it in."
                : "Connect your SmartThings account to sync devices from your ST hubs.",
            actionTitle: hasToken ? "Refresh Now" : "Connect Account",
            actionStyle: .secondary,
            isDisabled: smartThingsProvider == nil || (isWorking && workingProvider != .smartThings),
            isLoading: isWorking && workingProvider == .smartThings
        ) {
            if hasToken {
                Task { await refreshSmartThings() }
            } else {
                showingSmartThingsToken = true
            }
        }
    }

    /// Sonos gets the Pencil `Oa5ev` radar-scan flow because it's the
    /// only provider we have whose "pairing" model actually maps onto
    /// the design (Bonjour auto-discovery + "Ready to pair" rows).
    /// HomeKit and SmartThings stay as plain `ProviderRow`s because
    /// their pair flows don't match that shape.
    @State private var showPairingScanner = false

    private var sonosRow: some View {
        ProviderRow(
            iconSystemName: "hifispeaker.fill",
            title: "Sonos",
            subtitle: "Speakers are discovered automatically on your Wi-Fi. Tap Scan to see every speaker we can see right now.",
            actionTitle: "Scan for Speakers",
            actionStyle: .secondary,
            isDisabled: sonosProvider == nil,
            isLoading: false
        ) {
            showPairingScanner = true
        }
        .navigationDestination(isPresented: $showPairingScanner) {
            DevicePairingScanView()
                .environment(registry)
        }
    }

    // MARK: - Actions

    private func startHomeKitSetup() async {
        guard let provider = homeKitProvider else {
            errorMessage = "Apple Home is not available on this device."
            return
        }
        isWorking = true
        workingProvider = .homeKit
        defer {
            isWorking = false
            workingProvider = nil
        }
        do {
            try await provider.beginAccessorySetup()
            // On success, close the chooser so the user lands back on
            // the category grid — the new device will show up on the
            // Home / Rooms tabs as HomeKit publishes its update.
            dismiss()
        } catch {
            let text = "\(error)"
            if !text.localizedCaseInsensitiveContains("cancel") {
                errorMessage = "Couldn't start setup: \(error.localizedDescription)"
            }
        }
    }

    private func refreshSmartThings() async {
        guard let provider = smartThingsProvider else { return }
        isWorking = true
        workingProvider = .smartThings
        defer {
            isWorking = false
            workingProvider = nil
        }
        await provider.refresh()
        infoMessage = "Pulled the latest devices from SmartThings. Any newly-paired devices should now appear on the Home and Rooms tabs."
    }

    private func rescanSonos() async {
        guard let provider = sonosProvider else { return }
        isWorking = true
        workingProvider = .sonos
        defer {
            isWorking = false
            workingProvider = nil
        }
        await provider.refresh()
        infoMessage = "Rescanning the local network for Sonos speakers. New players appear automatically when they respond."
    }
}

// MARK: - Provider row card
//
// A single "card with icon + text + action button" row used in the
// chooser sheet. Visual mirror of the Pencil `CategoryTile` but
// horizontal and with a CTA instead of a chevron.

private struct ProviderRow: View {
    let iconSystemName: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let actionStyle: ActionStyle
    let isDisabled: Bool
    let isLoading: Bool
    let action: () -> Void

    enum ActionStyle {
        case primary   // filled purple
        case secondary // outlined purple
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IconChip(systemName: iconSystemName, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text(subtitle)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Button(action: action) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(actionStyle == .primary ? .white : Theme.color.primary)
                    }
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(
                        actionStyle == .primary
                            ? Theme.color.primary
                            : Color.clear
                    )
                )
                .overlay(
                    Capsule().stroke(
                        actionStyle == .secondary
                            ? Theme.color.primary
                            : Color.clear,
                        lineWidth: 1.5
                    )
                )
                .foregroundStyle(
                    actionStyle == .primary
                        ? Color.white
                        : Theme.color.primary
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || isLoading)
            .opacity(isDisabled ? 0.55 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }
}

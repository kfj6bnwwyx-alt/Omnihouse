//
//  house_connectApp.swift
//  house connect
//
//  Created by brent brooks on 4/10/26.
//

import SwiftUI

@main
struct house_connectApp: App {
    /// Shared keychain store. Lives at app scope so every provider that needs
    /// a token gets the same instance. (It's cheap to recreate, but keeping
    /// it here documents the dependency.)
    @State private var tokenStore = KeychainTokenStore()

    /// The single source of truth for provider state across the whole app.
    /// Register each ecosystem here as it comes online.
    @State private var providerRegistry: ProviderRegistry

    /// User-defined scenes (Phase 3b). Persists to Application Support as
    /// JSON. Seeded with four starter tiles on first launch.
    @State private var sceneStore: SceneStore

    /// In-memory notification inbox (Pencil `mCjOM`). Seeded at app
    /// scope so every screen that wants to post an event sees the
    /// same ring buffer. Not persisted — on relaunch the feed is
    /// empty and fills up as providers come online.
    @State private var eventStore = AppEventStore()

    /// Live weather via Open-Meteo + CoreLocation. One shared instance
    /// so the Home card and any future weather-aware automation share
    /// the same cached reading.
    @State private var weatherService = WeatherService()

    /// Shared lookup for merged (dual-homed) device metadata. Populated
    /// by AllDevicesView; consumed by detail views for smart routing.
    @State private var mergedDeviceLookup = MergedDeviceLookup()

    /// Lifecycle owner for the smoke-alarm Live Activity. iOS-only —
    /// `ActivityKit` isn't available on macOS, and the app also builds
    /// for macOS, so we only instantiate the controller under iOS.
    #if os(iOS)
    @State private var smokeAlertController = SmokeAlertController()
    #endif

    /// Persisted smoke alarm event history. Shared so both the detail
    /// view and the alert controller can read/write events.
    @State private var smokeAlarmEventStore = SmokeAlarmEventStore()

    /// Energy statistics (today/hourly/monthly). Currently serves
    /// placeholder data derived from the current date — real HA
    /// `recorder/statistics_during_period` wiring pending.
    @State private var energyService = EnergyService()

    init() {
        let store = KeychainTokenStore()
        let registry = ProviderRegistry()
        registry.register(HomeKitProvider())
        registry.register(SmartThingsProvider(tokenStore: store))
        registry.register(SonosProvider())
        // Nest provider — use the real SDM-backed NestProvider when
        // Google Device Access credentials are present in Info.plist;
        // fall back to DemoNestProvider (publishes fake devices for UI
        // development) when they're absent.
        if let projectID = Bundle.main.infoDictionary?["NEST_PROJECT_ID"] as? String,
           let clientID = Bundle.main.infoDictionary?["NEST_CLIENT_ID"] as? String,
           !projectID.isEmpty, !clientID.isEmpty {
            // clientSecret is optional — iOS OAuth clients (public) don't have one.
            let clientSecret = Bundle.main.infoDictionary?["NEST_CLIENT_SECRET"] as? String
            let config = NestOAuthManager.Configuration(
                projectID: projectID,
                clientID: clientID,
                clientSecret: clientSecret?.isEmpty == true ? nil : clientSecret
            )
            registry.register(NestProvider(tokenStore: store, config: config))
        } else {
            registry.register(DemoNestProvider())
        }

        // Home Assistant — unified backend provider. Connects via
        // WebSocket for real-time state, routes commands through HA's
        // service call API. Replaces the need for per-ecosystem
        // adapters when HA handles those integrations natively.
        registry.register(HomeAssistantProvider(tokenStore: store))

        // Seed demo smoke alarm events so the Recent Events card has
        // content from the first launch. Only fires when the store is
        // empty for the demo Protect's native ID.
        let eventStore = SmokeAlarmEventStore()
        eventStore.seedIfEmpty(
            for: DemoNestProvider.demoProtectNativeID,
            events: [
                SmokeAlarmEvent(kind: .selfTestPassed,
                                date: Date().addingTimeInterval(-3 * 86400)),
                SmokeAlarmEvent(kind: .batteryCheck,
                                date: Date().addingTimeInterval(-7 * 86400)),
                SmokeAlarmEvent(kind: .wifiConnected,
                                date: Date().addingTimeInterval(-14 * 86400)),
            ]
        )
        _smokeAlarmEventStore = State(initialValue: eventStore)
        _tokenStore = State(initialValue: store)
        _providerRegistry = State(initialValue: registry)
        _sceneStore = State(initialValue: SceneStore())
    }

    /// User's preferred color scheme from Appearance settings. Maps
    /// the raw string to SwiftUI's `ColorScheme?` — nil = system default.
    @AppStorage("appearance.colorScheme") private var colorSchemeRaw: String = "system"

    private var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            // RootContainerView owns the SplashView → RootTabView flip.
            // Environments are injected here so both the splash and the
            // live app see them; SplashView ignores them but cheap.
            RootContainerView()
                .environment(providerRegistry)
                .environment(sceneStore)
                .environment(eventStore)
                .environment(weatherService)
                .environment(smokeAlarmEventStore)
                .environment(mergedDeviceLookup)
                .environment(energyService)
                #if os(iOS)
                .environment(smokeAlertController)
                #endif
                .preferredColorScheme(preferredScheme)
        }
    }
}

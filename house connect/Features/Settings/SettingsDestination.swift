//
//  SettingsDestination.swift
//  house connect
//
//  Navigation destination enum for settings subpages. Extracted from the
//  deleted `SettingsView.swift` (legacy) during the T3 migration on
//  2026-04-18. Keep this type here so `T3SettingsTabView`, `T3RootView`,
//  `ProviderDisconnectedBanner`, and `DeviceOfflineView` all share the
//  same destination vocabulary.
//

import SwiftUI

enum SettingsDestination: Hashable {
    case profile
    case providers
    case rooms
    case scenes
    case automations
    case audioZones
    case energy
    case haDiagnostics
    case networkTopology
    case about
    case helpFAQ
    case notifications
    case appearance
}

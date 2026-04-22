//
//  T3TabNavigator.swift
//  house connect
//
//  Shared navigation state for the T3 tab bar + NavigationStack path.
//  Lets sheets (e.g. T3AddDeviceSheet) switch tabs and push destinations
//  without wiring callbacks through the view tree.
//
//  Scope tradeoff: the app's single NavigationStack is shared across
//  tabs (see T3RootView), so pushing onto `settingsPath` while any tab
//  is selected will push on that stack. That's acceptable here because
//  the only current writer (AddDeviceSheet) sets `.settings` first and
//  then appends to the path — the tab-switch happens before the push
//  frame.
//

import SwiftUI
import Observation

@Observable
final class T3TabNavigator {
    /// Tab selection with a side effect: any time the user switches
    /// tabs we drop the shared NavigationStack path. Without this,
    /// detail views pushed on one tab stay retained when the user
    /// jumps to another tab — their `@State`, observers, and
    /// spawned `Task`s keep running in the background, and coming
    /// back to the original tab lands on the old deep screen
    /// instead of the tab root. That retention was a major
    /// contributor to the "slows down after 4–5 screens" freeze.
    var selection: T3Tab = .home {
        didSet {
            guard selection != oldValue else { return }
            // Collapse the path so the new tab root renders fresh.
            // Programmatic `goToSettings(_:)` below temporarily
            // violates this (it flips the tab THEN appends) — the
            // didSet runs first, which is exactly what we want.
            path = NavigationPath()
        }
    }
    /// Type-erased path driving the single NavigationStack in
    /// T3RootView. Type-erased because the stack handles multiple
    /// destination types (AccessoryID, Room, SettingsDestination, …).
    /// Shared across tabs today.
    var path: NavigationPath = NavigationPath()

    /// Convenience: switch to the Settings tab and push a settings
    /// destination onto the shared stack. Clears any prior path so the
    /// user lands on the pushed screen rather than deep-nested.
    func goToSettings(_ dest: SettingsDestination) {
        selection = .settings   // didSet clears the path
        path.append(dest)
    }
}

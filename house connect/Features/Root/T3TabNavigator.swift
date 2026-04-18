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
    var selection: T3Tab = .home
    /// Type-erased path driving the single NavigationStack in
    /// T3RootView. Type-erased because the stack handles multiple
    /// destination types (AccessoryID, Room, SettingsDestination, …).
    /// Shared across tabs today.
    var path: NavigationPath = NavigationPath()

    /// Convenience: switch to the Settings tab and push a settings
    /// destination onto the shared stack. Clears any prior path so the
    /// user lands on the pushed screen rather than deep-nested.
    func goToSettings(_ dest: SettingsDestination) {
        selection = .settings
        path = NavigationPath()
        path.append(dest)
    }
}

//
//  HouseConnectWidgetsBundle.swift
//  HouseConnectWidgets
//
//  @main entry point for the widget extension. Xcode's wizard scaffolded
//  a pair of sample widgets (HouseConnectWidgets + HouseConnectWidgetsControl)
//  which we deleted — House Connect's only widget-extension surface today
//  is the smoke-alarm Live Activity (Pencil nodes hYUFC / EY8wa / 3eyUA).
//  As we add more widgets (e.g. a Home scenes grid or a Now Playing tile),
//  list them alongside `SmokeAlertLiveActivity` below; `WidgetBundle` lets
//  a single extension expose N widgets.
//

import WidgetKit
import SwiftUI

@main
struct HouseConnectWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SmokeAlertLiveActivity()
        CameraWidget()
        ThermostatWidget()
        SceneRunWidget()
    }
}

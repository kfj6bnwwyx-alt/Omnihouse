//
//  HouseConnectWatchApp.swift
//  HouseConnectWatch
//
//  Entry point for the Apple Watch companion app. Uses a simple
//  NavigationStack with WatchHomeView as the root.
//
//  NOTE: Requires WatchKit App target. File → New → Target → watchOS →
//  App, name it "HouseConnectWatch". Then add all files in this
//  directory to that target.
//

import SwiftUI

// Commented out @main until the Watch target is created in Xcode.
// Uncomment when the target exists.
// @main
struct HouseConnectWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
        }
    }
}

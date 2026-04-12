//
//  ContentView.swift
//  house connect
//
//  Created by brent brooks on 4/10/26.
//

import SwiftUI

/// Thin wrapper kept for Xcode's default preview hookup. The app now uses
/// `RootTabView` at the root — see `house_connectApp.swift`.
struct ContentView: View {
    var body: some View {
        RootTabView()
    }
}

#Preview {
    ContentView()
        .environment(ProviderRegistry())
        .environment(SceneStore())
}

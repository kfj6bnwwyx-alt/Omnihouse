//
//  T3TabBar.swift
//  house connect
//
//  T3/Swiss floating tab bar — white panel with hairline border,
//  4 tabs with dot accent on active. Floats above content.
//  Matches Claude Design handoff T3Tabs component.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3TabBar: View {
    @Binding var selection: T3Tab
    /// Called when the user taps the CURRENTLY SELECTED tab. The
    /// convention (matching Apple Home, Mail, and most iOS apps)
    /// is to pop the navigation stack back to the tab's root.
    /// T3RootView wires this to `navigator.path = NavigationPath()`.
    var onReselect: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(T3Tab.allCases, id: \.self) { tab in
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    if selection == tab {
                        // Re-tap on the active tab → pop to root.
                        onReselect?()
                        return
                    }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            T3IconImage(systemName: tab.icon)
                                .frame(width: 22, height: 22)
                                .foregroundStyle(selection == tab ? T3.ink : T3.sub)

                            if selection == tab {
                                TDot(size: 5)
                                    .offset(x: 6, y: -1)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }

                        Text(tab.label)
                            .font(T3.inter(10, weight: .semibold))
                            .foregroundStyle(selection == tab ? T3.ink : T3.sub)
                            .opacity(selection == tab ? 1 : 0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selection)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: T3.tabBarRadius)
                .fill(T3.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: T3.tabBarRadius)
                        .stroke(T3.rule, lineWidth: 1)
                )
                .shadow(color: T3.tabBarShadow, radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

enum T3Tab: String, CaseIterable {
    case home, rooms, devices, settings

    var label: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .rooms: "square.grid.2x2"
        case .devices: "circle.grid.3x3"
        case .settings: "gearshape"
        }
    }
}

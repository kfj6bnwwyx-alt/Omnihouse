//
//  T3TabBar.swift
//  house connect
//
//  T3/Swiss floating tab bar — white panel with hairline border,
//  4 tabs with dot accent on active. Floats above content.
//  Matches Claude Design handoff T3Tabs component.
//

import SwiftUI

struct T3TabBar: View {
    @Binding var selection: T3Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(T3Tab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: selection == tab ? .semibold : .regular))
                                .foregroundStyle(selection == tab ? T3.ink : T3.sub)

                            if selection == tab {
                                TDot(size: 5)
                                    .offset(x: 4, y: -2)
                            }
                        }

                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selection == tab ? T3.ink : T3.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
        }
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

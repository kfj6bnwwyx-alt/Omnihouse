//
//  AppearanceView.swift
//  house connect
//
//  Settings → Preferences → Appearance. T3/Swiss rewrite 2026-04-18.
//  Three radio groups (theme / units / density), all @AppStorage-backed,
//  same keys as before so the preferences persist across the migration.
//

import SwiftUI

struct AppearanceView: View {
    @AppStorage("appearance.colorScheme") private var colorSchemeRaw: String = "system"
    @AppStorage("appearance.tempUnit") private var tempUnitRaw: String = "celsius"
    @AppStorage("appearance.compactDashboard") private var compactDashboard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Appearance.", subtitle: "Theme, units & display")

                // Theme
                TSectionHead(title: "Theme", count: "03")
                radioRow(title: "System", sub: "MATCH IOS SETTING",
                         isOn: colorSchemeRaw == "system") { colorSchemeRaw = "system" }
                radioRow(title: "Light", sub: "ALWAYS LIGHT MODE",
                         isOn: colorSchemeRaw == "light") { colorSchemeRaw = "light" }
                radioRow(title: "Dark", sub: "ALWAYS DARK MODE",
                         isOn: colorSchemeRaw == "dark", isLast: true) { colorSchemeRaw = "dark" }

                // Units
                TSectionHead(title: "Temperature", count: "02")
                radioRow(title: "Celsius", sub: "°C",
                         isOn: tempUnitRaw == "celsius") { tempUnitRaw = "celsius" }
                radioRow(title: "Fahrenheit", sub: "°F",
                         isOn: tempUnitRaw == "fahrenheit", isLast: true) { tempUnitRaw = "fahrenheit" }

                // Density
                TSectionHead(title: "Dashboard", count: "")
                densityToggle(title: "Compact layout",
                              sub: "TIGHTER SPACING · MORE ON SCREEN",
                              isOn: $compactDashboard, isLast: true)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    private func radioRow(title: String, sub: String, isOn: Bool,
                          isLast: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(T3.ink, lineWidth: 1)
                        .frame(width: 18, height: 18)
                    if isOn {
                        Circle()
                            .fill(T3.accent)
                            .frame(width: 9, height: 9)
                    }
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    TLabel(text: sub)
                }
                Spacer()
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func densityToggle(title: String, sub: String, isOn: Binding<Bool>,
                               isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: sub)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(T3.accent)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

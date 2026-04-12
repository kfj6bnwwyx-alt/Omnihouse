//
//  AppearanceView.swift
//  house connect
//
//  Appearance settings reached from Settings → Preferences → Appearance.
//  Controls color scheme (system/light/dark), temperature unit (°C/°F),
//  and dashboard layout density. All preferences are @AppStorage-backed.
//
//  The color scheme override uses UIKit's `overrideUserInterfaceStyle`
//  via the scene delegate or a root-level modifier — this view just
//  stores the preference. The actual override is applied in the app's
//  root view (house_connectApp.swift).
//

import SwiftUI

struct AppearanceView: View {
    @AppStorage("appearance.colorScheme") private var colorSchemeRaw: String = "system"
    @AppStorage("appearance.tempUnit") private var tempUnitRaw: String = "celsius"
    @AppStorage("appearance.compactDashboard") private var compactDashboard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                    .padding(.top, 8)
                themeSection
                unitsSection
                layoutSection
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        SettingsSubpageHeader(title: "Appearance", subtitle: "Theme, units & display")
    }

    // MARK: - Theme

    private var themeSection: some View {
        settingsSection(title: "THEME") {
            VStack(spacing: 0) {
                themeOption(title: "System", subtitle: "Match iOS setting", value: "system")
                themeOption(title: "Light", subtitle: "Always light mode", value: "light")
                themeOption(title: "Dark", subtitle: "Always dark mode", value: "dark")
            }
        }
    }

    private func themeOption(title: String, subtitle: String, value: String) -> some View {
        Button {
            colorSchemeRaw = value
        } label: {
            HStack(spacing: 14) {
                IconChip(
                    systemName: iconForTheme(value),
                    size: 40,
                    fill: colorSchemeRaw == value
                        ? Theme.color.primary.opacity(0.12)
                        : Theme.color.iconChipFill,
                    glyph: colorSchemeRaw == value
                        ? Theme.color.primary
                        : Theme.color.iconChipGlyph
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text(subtitle)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                }
                Spacer()
                if colorSchemeRaw == value {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.color.primary)
                } else {
                    Circle()
                        .stroke(Theme.color.divider, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) theme")
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(colorSchemeRaw == value ? [.isSelected] : [])
    }

    private func iconForTheme(_ value: String) -> String {
        switch value {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        settingsSection(title: "UNITS") {
            VStack(spacing: 0) {
                unitOption(title: "Celsius", subtitle: "°C temperature display", value: "celsius")
                unitOption(title: "Fahrenheit", subtitle: "°F temperature display", value: "fahrenheit")
            }
        }
    }

    private func unitOption(title: String, subtitle: String, value: String) -> some View {
        Button {
            tempUnitRaw = value
        } label: {
            HStack(spacing: 14) {
                IconChip(systemName: "thermometer", size: 40,
                         fill: tempUnitRaw == value
                            ? Theme.color.primary.opacity(0.12)
                            : Theme.color.iconChipFill,
                         glyph: tempUnitRaw == value
                            ? Theme.color.primary
                            : Theme.color.iconChipGlyph)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text(subtitle)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                }
                Spacer()
                if tempUnitRaw == value {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.color.primary)
                } else {
                    Circle()
                        .stroke(Theme.color.divider, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) temperature unit")
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(tempUnitRaw == value ? [.isSelected] : [])
    }

    // MARK: - Layout

    private var layoutSection: some View {
        settingsSection(title: "LAYOUT") {
            HStack(spacing: 14) {
                IconChip(systemName: "square.grid.2x2", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compact Dashboard")
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                    Text("Smaller room tiles, more visible at once")
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                }
                Spacer()
                Toggle("", isOn: $compactDashboard)
                    .labelsHidden()
                    .tint(Theme.color.primary)
                    .accessibilityLabel("Compact Dashboard")
                    .accessibilityHint("Smaller room tiles, more visible at once")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.subtitle)
                .tracking(0.8)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content()
            }
            .hcCard(padding: 0)
        }
    }
}

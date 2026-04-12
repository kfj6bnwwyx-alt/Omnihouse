//
//  NotificationPreferencesView.swift
//  house connect
//
//  Notification preferences reached from Settings → Preferences →
//  Notifications. Controls which event categories generate push
//  notifications and in-app banners. All toggles are @AppStorage-
//  backed so they persist across launches.
//
//  These preferences are UI-only right now — the app doesn't send real
//  push notifications yet (requires APNs entitlement + server). The
//  toggles are wired so that when push is added later, the stored
//  preferences are already in place.
//

import SwiftUI

struct NotificationPreferencesView: View {
    @AppStorage("notif.deviceOffline") private var deviceOffline = true
    @AppStorage("notif.deviceOnline") private var deviceOnline = false
    @AppStorage("notif.sceneRun") private var sceneRun = true
    @AppStorage("notif.smokeAlarm") private var smokeAlarm = true
    @AppStorage("notif.motionDetected") private var motionDetected = true
    @AppStorage("notif.doorLock") private var doorLock = true
    @AppStorage("notif.temperatureAlert") private var temperatureAlert = true
    @AppStorage("notif.inAppBanner") private var inAppBanner = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                    .padding(.top, 8)
                alertsSection
                activitySection
                displaySection
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
        SettingsSubpageHeader(title: "Notifications", subtitle: "Choose what alerts you")
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        settingsSection(title: "ALERTS") {
            toggleRow(icon: "exclamationmark.triangle.fill",
                      title: "Smoke & CO Alarms",
                      subtitle: "Critical safety alerts",
                      isOn: $smokeAlarm)
            toggleRow(icon: "thermometer.high",
                      title: "Temperature Alerts",
                      subtitle: "Out-of-range warnings",
                      isOn: $temperatureAlert)
            toggleRow(icon: "lock.fill",
                      title: "Door & Lock Activity",
                      subtitle: "Lock/unlock events",
                      isOn: $doorLock)
            toggleRow(icon: "video.fill",
                      title: "Motion Detected",
                      subtitle: "Camera motion events",
                      isOn: $motionDetected)
        }
    }

    // MARK: - Activity

    private var activitySection: some View {
        settingsSection(title: "ACTIVITY") {
            toggleRow(icon: "wifi.slash",
                      title: "Device Offline",
                      subtitle: "When a device becomes unreachable",
                      isOn: $deviceOffline)
            toggleRow(icon: "wifi",
                      title: "Device Online",
                      subtitle: "When a device reconnects",
                      isOn: $deviceOnline)
            toggleRow(icon: "sparkles",
                      title: "Scene Executed",
                      subtitle: "Confirmation after running a scene",
                      isOn: $sceneRun)
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        settingsSection(title: "DISPLAY") {
            toggleRow(icon: "app.badge.fill",
                      title: "In-App Banners",
                      subtitle: "Show toast notifications within the app",
                      isOn: $inAppBanner)
        }
    }

    // MARK: - Building blocks

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

    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            IconChip(systemName: icon, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text(subtitle)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.color.primary)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

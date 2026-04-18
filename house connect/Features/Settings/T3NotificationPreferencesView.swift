//
//  T3NotificationPreferencesView.swift
//  house connect
//
//  Settings → Preferences → Notifications. T3 rename 2026-04-18 with
//  a11y labels, Dynamic Type clamp, and the shared TToggle primitive.
//
//  @AppStorage keys preserved verbatim:
//    notif.deviceOffline · notif.deviceOnline · notif.sceneRun ·
//    notif.smokeAlarm · notif.motionDetected · notif.doorLock ·
//    notif.temperatureAlert · notif.inAppBanner
//

import SwiftUI

struct T3NotificationPreferencesView: View {
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
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Notifications.", subtitle: "Choose what alerts you")

                // Alerts
                TSectionHead(title: "Alerts", count: "04")
                toggleRow(icon: "exclamationmark.triangle",
                          title: "Smoke & CO", sub: "CRITICAL SAFETY ALERTS",
                          isOn: $smokeAlarm)
                toggleRow(icon: "thermometer.medium",
                          title: "Temperature", sub: "OUT-OF-RANGE WARNINGS",
                          isOn: $temperatureAlert)
                toggleRow(icon: "lock",
                          title: "Door & Lock activity", sub: "LOCK · UNLOCK EVENTS",
                          isOn: $doorLock)
                toggleRow(icon: "video",
                          title: "Motion detected", sub: "CAMERA MOTION EVENTS",
                          isOn: $motionDetected, isLast: true)

                // Activity
                TSectionHead(title: "Activity", count: "03")
                toggleRow(icon: "wifi.slash",
                          title: "Device offline", sub: "WHEN SOMETHING BECOMES UNREACHABLE",
                          isOn: $deviceOffline)
                toggleRow(icon: "wifi",
                          title: "Device back online", sub: "WHEN CONNECTION RESTORES",
                          isOn: $deviceOnline)
                toggleRow(icon: "sparkles",
                          title: "Scene ran", sub: "AFTER EACH SCENE EXECUTES",
                          isOn: $sceneRun, isLast: true)

                // Display
                TSectionHead(title: "Display", count: "01")
                toggleRow(icon: "bell",
                          title: "In-app banner", sub: "SHOW TOASTS INSIDE THE APP",
                          isOn: $inAppBanner, isLast: true)

                // Foot
                Text("These preferences are stored locally. Push notifications ride on top of your iOS system settings — toggling them off here silences the banner in-app, but doesn't change your iOS allow-list.")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 20)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func toggleRow(icon: String, title: String, sub: String,
                           isOn: Binding<Bool>, isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: sub)
            }
            Spacer()
            TToggle(isOn: isOn, accessibilityLabel: title)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}

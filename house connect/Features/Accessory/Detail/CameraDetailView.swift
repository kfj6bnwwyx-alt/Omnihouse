//
//  CameraDetailView.swift
//  house connect
//
//  Bespoke detail screen for cameras. Matches Pencil node `UUlP4`.
//  Layout:
//    • Shared DeviceDetailHeader (power toggle hidden — cameras don't
//      expose a power capability in our vocabulary).
//    • Large live preview card with a red "LIVE" badge + resolution
//      tag in the corners. Reuses the existing `CameraPreview` which
//      dispatches to the right renderer per provider.
//    • 2×2 grid of action buttons: Record / Snapshot / Talk / Siren.
//      Snapshot triggers via CameraController → HMCameraSnapshotControl.
//      Talk toggles the camera microphone (two-way audio).
//      Record and Siren aren't available via HomeKit — shown as
//      "unavailable" with muted styling.
//    • Settings rows: Motion Detection, Night Vision, Push Notifications.
//      Night Vision wires through CameraController when the camera
//      supports it; the others are local toggles (pending real wiring).
//    • Recent Activity list: static placeholders.
//

import SwiftUI

struct CameraDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    @State private var cameraController = CameraController()
    @State private var motionDetection = true
    @State private var pushNotifications = true

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(spacing: 20) {
                        DeviceDetailHeader(
                            title: accessory.name,
                            subtitle: roomName,
                            isOn: nil,
                            onTogglePower: { _ in }
                        )
                        .padding(.top, 8)

                        livePreviewCard(for: accessory)
                        actionsGrid
                        settingsCard
                        activityCard
                        RemoveDeviceSection(accessoryID: accessoryID)
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "Camera unavailable",
                    systemImage: "video.slash"
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            cameraController.attach(accessoryID: accessoryID, registry: registry)
        }
        .alert("Camera",
               isPresented: Binding(
                get: { cameraController.statusMessage != nil },
                set: { if !$0 { cameraController.statusMessage = nil } }),
               actions: { Button("OK") { cameraController.statusMessage = nil } },
               message: { Text(cameraController.statusMessage ?? "") })
    }

    // MARK: - Live preview

    private func livePreviewCard(for accessory: Accessory) -> some View {
        ZStack(alignment: .topLeading) {
            CameraPreview(accessoryID: accessory.id)
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius.card,
                                            style: .continuous))

            // LIVE badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.55)))
            .padding(12)

            // 1080p tag
            VStack {
                HStack {
                    Spacer()
                    Text("1080p")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(12)
                }
                Spacer()
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera feed from \(accessory.name)")
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Actions grid

    /// 2×2 grid: Snapshot and Talk are live actions wired through
    /// CameraController. Record and Siren aren't available via HomeKit
    /// and render as disabled with a small "unavailable" label.
    private var actionsGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            // Snapshot — triggers HMCameraSnapshotControl
            actionTile(
                icon: "camera.fill",
                label: "Snapshot",
                isEnabled: cameraController.hasSnapshot,
                isLoading: cameraController.isTakingSnapshot
            ) {
                cameraController.takeSnapshot()
            }

            // Talk — toggles the camera's microphone (two-way audio)
            actionTile(
                icon: cameraController.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                label: cameraController.isMicrophoneMuted ? "Talk" : "Talking…",
                isEnabled: cameraController.hasMicrophone,
                isActive: !cameraController.isMicrophoneMuted
            ) {
                cameraController.toggleMicrophone()
            }

            // Record — not available via HomeKit API
            actionTile(
                icon: "record.circle",
                label: "Record",
                isEnabled: false,
                unavailableHint: "Use Circle app"
            ) { }

            // Siren — not available via HomeKit API
            actionTile(
                icon: "bell.badge.fill",
                label: "Siren",
                isEnabled: false,
                unavailableHint: "Use Circle app"
            ) { }
        }
    }

    private func actionTile(
        icon: String,
        label: String,
        isEnabled: Bool,
        isLoading: Bool = false,
        isActive: Bool = false,
        unavailableHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                        .fill(isActive ? Theme.color.primary : Theme.color.iconChipFill)
                        .frame(width: 44, height: 44)
                    if isLoading {
                        ProgressView()
                            .tint(isActive ? .white : Theme.color.iconChipGlyph)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isActive ? .white : Theme.color.iconChipGlyph)
                    }
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEnabled ? Theme.color.title : Theme.color.muted)
                if let hint = unavailableHint {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.color.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .hcCard(padding: 0)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(
            !isEnabled
                ? (unavailableHint ?? "Unavailable")
                : isLoading ? "Loading" : ""
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isEnabled ? [] : .isButton)
        .accessibilityAddTraits(!isEnabled ? .isStaticText : [])
    }

    // MARK: - Settings card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            toggleRow(
                icon: "figure.walk.motion",
                title: "Motion Detection",
                subtitle: "Notify when movement is detected",
                isOn: $motionDetection
            )
            Divider().padding(.leading, 56)

            // Night Vision — wired through CameraController when supported,
            // otherwise falls back to a local toggle (visual only).
            if cameraController.hasNightVision {
                toggleRow(
                    icon: "moon.fill",
                    title: "Night Vision",
                    subtitle: "Enhanced low-light visibility",
                    isOn: Binding(
                        get: { cameraController.nightVisionEnabled },
                        set: { _ in cameraController.toggleNightVision() }
                    )
                )
                Divider().padding(.leading, 56)
            }

            toggleRow(
                icon: "bell.fill",
                title: "Push Notifications",
                subtitle: "Receive alerts on this device",
                isOn: $pushNotifications
            )

            // Speaker mute toggle — only shown if the camera has a speaker
            if cameraController.hasSpeaker {
                Divider().padding(.leading, 56)
                toggleRow(
                    icon: "speaker.wave.2.fill",
                    title: "Camera Speaker",
                    subtitle: "Audio from camera to your phone",
                    isOn: Binding(
                        get: { !cameraController.isSpeakerMuted },
                        set: { _ in cameraController.toggleSpeaker() }
                    )
                )
            }
        }
        .hcCard(padding: 0)
    }

    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.subtitle)
            }
            .accessibilityHidden(true)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Theme.color.primary)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
        .padding(.horizontal, Theme.space.cardPadding)
        .padding(.vertical, 12)
    }

    // MARK: - Activity card

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Spacer()
                Text("Today")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }

            if cameraController.recentActivity.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.color.muted)
                    Text("No recent activity")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.color.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("No recent activity")
            } else {
                ForEach(cameraController.recentActivity, id: \.title) { event in
                    activityRow(icon: event.icon, title: event.title, time: event.time)
                }
            }
        }
        .hcCard()
    }

    private func activityRow(icon: String, title: String, time: String) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon, size: 32)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.color.title)
            Spacer()
            Text(time)
                .font(.system(size: 12))
                .foregroundStyle(Theme.color.muted)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(time)")
    }
}

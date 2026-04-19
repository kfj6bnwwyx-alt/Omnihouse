//
//  CameraController.swift
//  house connect
//
//  Observable controller for camera-specific actions that go beyond the
//  unified AccessoryCommand vocabulary. HomeKit cameras expose snapshot,
//  microphone, speaker, and night-vision controls via HMCameraProfile —
//  none of those map cleanly onto the generic provider protocol, so this
//  controller talks directly to HomeKit. When SmartThings / Nest cameras
//  come online, we'll add provider-dispatching here (same pattern as
//  T3CameraDetailView's content switch).
//
//  Lifecycle:
//    • CameraDetailView creates a @State CameraController on appear.
//    • CameraDetailView calls `attach(accessoryID:registry:)` once.
//    • The controller reads the HMCameraProfile's sub-controls and
//      publishes capability booleans (hasSnapshot, hasMicrophone, …).
//    • Action methods (takeSnapshot, toggleMicrophone, …) are now
//      `async throws`. Errors propagate to the caller so detail views
//      can surface them via T3ActionFeedback (haptic + toast + log)
//      instead of swallowing into a local statusMessage.
//

import Foundation
import Observation

#if canImport(HomeKit)
import HomeKit
#endif

/// Errors thrown by CameraController when the camera has no capability
/// for the requested action (e.g. no snapshot control, no microphone).
enum CameraControllerError: LocalizedError {
    case noSnapshotControl
    case noMicrophone
    case noSpeaker
    case noNightVision
    case snapshotFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noSnapshotControl: return "Camera has no snapshot control."
        case .noMicrophone:      return "Camera has no microphone."
        case .noSpeaker:         return "Camera has no speaker."
        case .noNightVision:     return "Camera has no night-vision setting."
        case .snapshotFailed(let e): return "Snapshot failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
@Observable
final class CameraController {

    // MARK: - Published capability flags (drive which buttons are enabled)

    /// True when the camera has a snapshot control we can invoke.
    private(set) var hasSnapshot: Bool = false

    /// True when the camera has a microphone we can mute/unmute
    /// (two-way audio / "Talk" button).
    private(set) var hasMicrophone: Bool = false

    /// True when the camera has a speaker we can mute/unmute.
    private(set) var hasSpeaker: Bool = false

    /// True when the camera supports night vision (from settingsControl).
    private(set) var hasNightVision: Bool = false

    // MARK: - Published state

    private(set) var isMicrophoneMuted: Bool = true
    private(set) var isSpeakerMuted: Bool = false
    private(set) var nightVisionEnabled: Bool = false

    /// Secondary status line (e.g. "Snapshot taken"). Errors no longer
    /// land here — detail views route those through T3ActionFeedback.
    var statusMessage: String?

    /// Simple activity event for the Recent Activity card.
    struct ActivityEvent: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let time: String
    }

    /// Recent activity events. Currently empty — real events will be
    /// populated from provider push notifications / polling in a future phase.
    private(set) var recentActivity: [ActivityEvent] = []

    /// True while a snapshot save is in progress.
    private(set) var isTakingSnapshot: Bool = false

    // MARK: - Private HomeKit handles

    #if canImport(HomeKit)
    @ObservationIgnored private var cameraProfile: HMCameraProfile?
    @ObservationIgnored private var snapshotControl: HMCameraSnapshotControl?
    @ObservationIgnored private var micMuteCharacteristic: HMCharacteristic?
    @ObservationIgnored private var speakerMuteCharacteristic: HMCharacteristic?
    @ObservationIgnored private var nightVisionCharacteristic: HMCharacteristic?
    @ObservationIgnored private var snapshotDelegate: SnapshotDelegate?
    #endif

    // MARK: - Attach

    /// Reads the camera profile from the HomeKit provider and populates
    /// the published capability flags. Safe to call multiple times —
    /// subsequent calls are no-ops if already attached.
    func attach(accessoryID: AccessoryID, registry: ProviderRegistry) {
        #if canImport(HomeKit)
        guard cameraProfile == nil else { return }
        guard accessoryID.provider == .homeKit,
              let hk = registry.provider(for: .homeKit) as? HomeKitProvider,
              let profile = hk.cameraProfile(forNativeID: accessoryID.nativeID) else {
            return
        }

        self.cameraProfile = profile

        // Snapshot
        if profile.snapshotControl != nil {
            self.snapshotControl = profile.snapshotControl
            self.hasSnapshot = true
        }

        // Microphone (two-way audio)
        // HMCameraAudioControl.mute is an HMCharacteristic (nullable).
        if let mic = profile.microphoneControl, let muteChar = mic.mute {
            self.micMuteCharacteristic = muteChar
            self.hasMicrophone = true
            self.isMicrophoneMuted = (muteChar.value as? NSNumber)?.boolValue ?? true
        }

        // Speaker
        if let spk = profile.speakerControl, let muteChar = spk.mute {
            self.speakerMuteCharacteristic = muteChar
            self.hasSpeaker = true
            self.isSpeakerMuted = (muteChar.value as? NSNumber)?.boolValue ?? false
        }

        // Night Vision — direct property on HMCameraSettingsControl.
        if let settings = profile.settingsControl, let nvChar = settings.nightVision {
            self.nightVisionCharacteristic = nvChar
            self.hasNightVision = true
            self.nightVisionEnabled = (nvChar.value as? NSNumber)?.boolValue ?? false
        }

        // Kick off reads for characteristics that might have stale/nil values
        Task { await readCurrentValues() }
        #endif
    }

    // MARK: - Actions

    /// Take a snapshot via the HomeKit snapshot control. Throws if the
    /// camera has no snapshot capability or the snapshot call fails.
    func takeSnapshot() async throws {
        #if canImport(HomeKit)
        guard let sc = snapshotControl else {
            throw CameraControllerError.noSnapshotControl
        }
        isTakingSnapshot = true
        statusMessage = nil

        // Bridge the delegate callback into an async throws call.
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let delegate = SnapshotDelegate { _, error in
                    if let error {
                        cont.resume(throwing: CameraControllerError.snapshotFailed(error))
                    } else {
                        cont.resume(returning: ())
                    }
                }
                self.snapshotDelegate = delegate
                sc.delegate = delegate
                sc.takeSnapshot()
            }
            isTakingSnapshot = false
            statusMessage = "Snapshot taken"
        } catch {
            isTakingSnapshot = false
            throw error
        }
        #else
        throw CameraControllerError.noSnapshotControl
        #endif
    }

    /// Toggle the camera's microphone (two-way audio). Throws on
    /// missing capability or provider write failure.
    func toggleMicrophone() async throws {
        #if canImport(HomeKit)
        guard let ch = micMuteCharacteristic else {
            throw CameraControllerError.noMicrophone
        }
        let newMuted = !isMicrophoneMuted
        try await ch.writeValue(NSNumber(value: newMuted))
        self.isMicrophoneMuted = newMuted
        #else
        throw CameraControllerError.noMicrophone
        #endif
    }

    /// Toggle the camera's speaker. Throws on missing capability or
    /// provider write failure.
    func toggleSpeaker() async throws {
        #if canImport(HomeKit)
        guard let ch = speakerMuteCharacteristic else {
            throw CameraControllerError.noSpeaker
        }
        let newMuted = !isSpeakerMuted
        try await ch.writeValue(NSNumber(value: newMuted))
        self.isSpeakerMuted = newMuted
        #else
        throw CameraControllerError.noSpeaker
        #endif
    }

    /// Toggle night vision on/off. Throws on missing capability or
    /// provider write failure.
    func toggleNightVision() async throws {
        #if canImport(HomeKit)
        guard let ch = nightVisionCharacteristic else {
            throw CameraControllerError.noNightVision
        }
        let newValue = !nightVisionEnabled
        try await ch.writeValue(NSNumber(value: newValue))
        self.nightVisionEnabled = newValue
        #else
        throw CameraControllerError.noNightVision
        #endif
    }

    // MARK: - Private helpers

    #if canImport(HomeKit)
    /// Reads live values for all attached characteristics to ensure
    /// the UI reflects current state (HomeKit may have stale caches).
    private func readCurrentValues() async {
        if let ch = micMuteCharacteristic {
            try? await ch.readValue()
            isMicrophoneMuted = (ch.value as? NSNumber)?.boolValue ?? true
        }
        if let ch = speakerMuteCharacteristic {
            try? await ch.readValue()
            isSpeakerMuted = (ch.value as? NSNumber)?.boolValue ?? false
        }
        if let ch = nightVisionCharacteristic {
            try? await ch.readValue()
            nightVisionEnabled = (ch.value as? NSNumber)?.boolValue ?? false
        }
    }

    // MARK: - Snapshot delegate

    private final class SnapshotDelegate: NSObject, HMCameraSnapshotControlDelegate {
        let handler: @Sendable (HMCameraSnapshot?, Error?) -> Void

        init(handler: @escaping @Sendable (HMCameraSnapshot?, Error?) -> Void) {
            self.handler = handler
        }

        nonisolated func cameraSnapshotControl(
            _ control: HMCameraSnapshotControl,
            didTake snapshot: HMCameraSnapshot?,
            error: Error?
        ) {
            handler(snapshot, error)
        }

        nonisolated func cameraSnapshotControlDidUpdateMostRecentSnapshot(
            _ control: HMCameraSnapshotControl
        ) {
            // Periodic updates — not needed for our on-demand snapshot flow.
        }
    }
    #endif
}

//
//  HomeKitCameraView.swift
//  house connect
//
//  Wraps Apple's HMCameraView (a UIView subclass) so SwiftUI can render live
//  HomeKit camera feeds. HMCameraView is the ONLY public way to display a
//  HomeKit camera — HMCameraSnapshot has no `imageData` property, and Apple
//  doesn't expose raw H.264 frames. You hand HMCameraView a camera source
//  and it renders itself.
//
//  Lifecycle:
//    1. View appears → Coordinator.attach() grabs the HMCameraProfile via
//       HomeKitProvider, calls streamControl.startStream(), assigns the
//       resulting HMCameraStream to HMCameraView.cameraSource.
//    2. If streaming isn't supported, falls back to snapshotControl.
//    3. View disappears → Coordinator.detach() stops the stream cleanly.
//
//  State is published via HomeKitCameraState (@Observable) so SwiftUI can
//  show loading/error overlays without round-tripping through bindings.
//

import SwiftUI
import HomeKit
import UIKit
import Observation

/// Observable state the `T3CameraDetailView` uses to show loading / error UI.
@MainActor
@Observable
final class HomeKitCameraState {
    var isStreaming: Bool = false
    var errorMessage: String?
}

struct HomeKitCameraView: UIViewRepresentable {
    let accessoryNativeID: String
    let provider: HomeKitProvider
    let state: HomeKitCameraState

    func makeCoordinator() -> Coordinator {
        Coordinator(provider: provider,
                    accessoryNativeID: accessoryNativeID,
                    state: state)
    }

    func makeUIView(context: Context) -> HMCameraView {
        let view = HMCameraView()
        view.backgroundColor = .black
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: HMCameraView, context: Context) {
        // Coordinator handles everything; no-op on update.
    }

    static func dismantleUIView(_ uiView: HMCameraView, coordinator: Coordinator) {
        coordinator.detach()
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, HMCameraStreamControlDelegate, HMCameraSnapshotControlDelegate {
        let provider: HomeKitProvider
        let accessoryNativeID: String
        let state: HomeKitCameraState

        private weak var cameraView: HMCameraView?
        private var streamControl: HMCameraStreamControl?
        private var snapshotControl: HMCameraSnapshotControl?

        init(provider: HomeKitProvider,
             accessoryNativeID: String,
             state: HomeKitCameraState) {
            self.provider = provider
            self.accessoryNativeID = accessoryNativeID
            self.state = state
        }

        func attach(to view: HMCameraView) {
            self.cameraView = view
            state.errorMessage = nil

            guard let profile = provider.cameraProfile(forNativeID: accessoryNativeID) else {
                state.errorMessage = "No camera profile for this accessory."
                return
            }

            // Prefer live stream; fall back to snapshot.
            if let sc = profile.streamControl {
                self.streamControl = sc
                sc.delegate = self

                // If a stream is already active (e.g. view was recreated), use it.
                if let existing = sc.cameraStream {
                    view.cameraSource = existing
                    state.isStreaming = true
                } else {
                    sc.startStream()
                }
            } else if let ss = profile.snapshotControl {
                self.snapshotControl = ss
                ss.delegate = self
                if let existing = ss.mostRecentSnapshot {
                    view.cameraSource = existing
                }
                ss.takeSnapshot()
            } else {
                state.errorMessage = "This camera exposes neither a stream nor a snapshot control."
            }
        }

        func detach() {
            streamControl?.stopStream()
            streamControl?.delegate = nil
            streamControl = nil
            snapshotControl?.delegate = nil
            snapshotControl = nil
            cameraView = nil
            state.isStreaming = false
        }

        // MARK: - HMCameraStreamControlDelegate

        nonisolated func cameraStreamControlDidStartStream(_ control: HMCameraStreamControl) {
            Task { @MainActor in
                if let stream = control.cameraStream {
                    self.cameraView?.cameraSource = stream
                    self.state.isStreaming = true
                    self.state.errorMessage = nil
                }
            }
        }

        nonisolated func cameraStreamControl(_ control: HMCameraStreamControl,
                                              didStopStreamWithError error: Error?) {
            let message = error?.localizedDescription
            Task { @MainActor in
                self.state.isStreaming = false
                if let message {
                    self.state.errorMessage = message
                }
            }
        }

        // MARK: - HMCameraSnapshotControlDelegate

        nonisolated func cameraSnapshotControl(_ control: HMCameraSnapshotControl,
                                                didTake snapshot: HMCameraSnapshot?,
                                                error: Error?) {
            let message = error?.localizedDescription
            Task { @MainActor in
                if let snapshot {
                    self.cameraView?.cameraSource = snapshot
                    self.state.errorMessage = nil
                } else if let message {
                    self.state.errorMessage = message
                }
            }
        }

        nonisolated func cameraSnapshotControlDidUpdateMostRecentSnapshot(_ control: HMCameraSnapshotControl) {
            Task { @MainActor in
                if let snap = control.mostRecentSnapshot {
                    self.cameraView?.cameraSource = snap
                }
            }
        }
    }
}

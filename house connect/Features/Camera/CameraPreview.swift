//
//  CameraPreview.swift
//  house connect
//
//  Provider-dispatching camera view. Each ecosystem has a totally different
//  transport (HomeKit = HMCameraView; SmartThings = HLS URL; Nest = WebRTC),
//  so we pick the right renderer per provider rather than pretending there's
//  a unified camera type. When SmartThings/Nest cameras come online, add a
//  case here that builds their provider-specific view.
//

import SwiftUI

struct CameraPreview: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @State private var hkState = HomeKitCameraState()

    var body: some View {
        ZStack {
            Color.black
            content
            overlay
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Dispatch

    @ViewBuilder
    private var content: some View {
        switch accessoryID.provider {
        case .homeKit:
            homeKitContent
        case .smartThings, .nest, .sonos:
            unavailable("Camera preview not yet implemented for this provider.")
        case .homeAssistant:
            if let haProvider = registry.provider(for: .homeAssistant) as? HomeAssistantProvider,
               let proxyURL = haProvider.cameraProxyURL(entityID: accessoryID.nativeID) {
                AsyncImage(url: proxyURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else {
                unavailable("Camera not available via Home Assistant.")
            }
        }
    }

    @ViewBuilder
    private var homeKitContent: some View {
        if let hk = registry.provider(for: .homeKit) as? HomeKitProvider {
            HomeKitCameraView(
                accessoryNativeID: accessoryID.nativeID,
                provider: hk,
                state: hkState
            )
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
        } else {
            unavailable("HomeKit provider not available.")
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var overlay: some View {
        if let message = hkState.errorMessage {
            errorOverlay(message)
        } else if accessoryID.provider == .homeKit && !hkState.isStreaming {
            ProgressView()
                .tint(.white)
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash")
                .font(.title)
                .foregroundStyle(.white.opacity(0.6))
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

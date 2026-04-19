//
//  T3CameraUnsupportedHelpView.swift
//  house connect
//
//  Guidance card shown from T3CameraDetailView when the camera either
//  doesn't expose a live stream (no HA integration, no RTSP URL, no
//  HomeKit camera profile) or the user taps the "Why isn't this
//  working?" link on the feed panel. Warm, explanatory tone — this is
//  not an error screen, it's a help page.
//
//  Common trigger: a Logitech Circle that shows up via HomeKit Secure
//  Video only, but the HA instance isn't bridging HomeKit Controller —
//  the entity exists but has no stream_source and state reads
//  "unavailable" forever.
//

import SwiftUI

struct T3CameraUnsupportedHelpView: View {
    let accessoryName: String
    let providerLabel: String
    /// Short reason to show in the status strip. One of "UNSUPPORTED",
    /// "NO STREAM URL", "OFFLINE", etc.
    let reasonCode: String

    @Environment(\.dismiss) private var dismiss

    private let docsURL = URL(string: "https://www.home-assistant.io/integrations/#camera")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                THeader(backLabel: "BACK", rightLabel: reasonCode) {
                    dismiss()
                }

                // Hero
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        T3IconImage(systemName: "questionmark.circle")
                            .frame(width: 28, height: 28)
                            .foregroundStyle(T3.ink)
                        TLabel(text: "CAMERA HELP  ·  \(providerLabel)")
                    }

                    Text("This camera isn't fully supported.")
                        .font(T3.inter(32, weight: .medium))
                        .tracking(-0.9)
                        .foregroundStyle(T3.ink)
                        .lineSpacing(2)

                    Text("\(accessoryName) is visible to House Connect, but Home Assistant can't stream a live feed from it right now. Live video needs either an RTSP URL or a working manufacturer integration — many cloud-only cameras don't offer either.")
                        .font(T3.inter(14, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(4)
                        .padding(.top, 4)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Common reasons
                TSectionHead(title: "Common reasons", count: "03")
                bulletRow(index: "01",
                          title: "Proprietary cloud camera",
                          detail: "Logitech Circle (cloud shut down Sept 2022), Wyze Cam v1, older Arlo. These never expose a direct stream.")
                bulletRow(index: "02",
                          title: "Manufacturer integration not installed",
                          detail: "Home Assistant needs the brand's integration loaded under Settings → Devices & Services.")
                bulletRow(index: "03",
                          title: "Firmware doesn't expose RTSP",
                          detail: "Some cameras only talk to their own apps, even on local network.")

                // What to do
                TSectionHead(title: "What to do", count: "03 STEPS")
                stepRow(index: "A",
                        title: "Check for an HA integration",
                        detail: "Open Home Assistant → Settings → Devices & Services → Add Integration, then search your camera brand.")
                stepRow(index: "B",
                        title: "For Logitech Circle View",
                        detail: "Add the HomeKit Controller integration in HA. It bridges HomeKit Secure Video so Circle View cameras stream over local network.")
                stepRow(index: "C",
                        title: "For RTSP cameras",
                        detail: "Reolink, Amcrest, Hikvision, Unifi — use the Generic Camera integration and paste the RTSP URL from the camera's web UI.")

                // Actions
                VStack(spacing: 10) {
                    Button {
                        UIApplication.shared.open(docsURL)
                    } label: {
                        HStack(spacing: 10) {
                            T3IconImage(systemName: "arrow.up.right.square")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(T3.page)
                            Text("OPEN HA CAMERA INTEGRATIONS")
                                .font(T3.mono(12))
                                .tracking(2)
                                .foregroundStyle(T3.page)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(T3.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Home Assistant camera integrations documentation")

                    Button {
                        dismiss()
                    } label: {
                        Text("BACK TO CAMERA")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(Rectangle().stroke(T3.ink, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 24)

                // Foot
                HStack {
                    TLabel(text: "HELP  ·  \(providerLabel)")
                    Spacer()
                    TLabel(text: reasonCode)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 20)

                Spacer(minLength: 80)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Rows

    private func bulletRow(index: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            TLabel(text: index)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                Text(detail)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
    }

    private func stepRow(index: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(index)
                .font(T3.mono(11))
                .tracking(1.5)
                .foregroundStyle(T3.accent)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                Text(detail)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
    }
}

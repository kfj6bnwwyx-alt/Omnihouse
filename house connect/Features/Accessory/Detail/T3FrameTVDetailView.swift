//
//  T3FrameTVDetailView.swift
//  house connect
//
//  T3/Swiss detail for the Samsung Frame TV. Replaces the legacy
//  `FrameTVDetailView` (Pencil `GrzJY`). The Frame's defining feature is
//  "Art Mode" — when off, it displays ambient artwork — so we surface
//  that state first-class in the hero band and in the section head.
//
//  Data flows from the unified `Accessory.capabilities` model via the
//  ProviderRegistry. Commands route through `.setPower`, `.selectSource`,
//  `.setVolume`, `.setMute`, and `.setBrightness`.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3FrameTVDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var brightness: Double = 0.7
    @State private var colorTone: Double = 0.5
    @State private var lastBrightnessBucket: Int = -1

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var isOn: Bool { accessory?.isOn ?? false }

    private var isArtMode: Bool {
        guard let s = accessory?.currentSource?.lowercased() else { return false }
        return s.contains("art") || s.contains("ambient")
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: roomName != nil ? "Room" : "Devices",
                        rightLabel: isArtMode ? "ART MODE" : (isOn ? "ON" : "OFF"),
                        showDot: isOn,
                        onBack: { dismiss() }
                    )

                    TTitle(
                        title: accessory?.name ?? "Frame TV",
                        subtitle: roomName,
                        isActive: isOn
                    )

                    TSectionHead(
                        title: "Samsung Frame",
                        count: isArtMode ? "ART MODE · ON" : (isOn ? "ON" : "OFF")
                    )

                    heroPanel
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 18)

                    TRule()

                    // Power + art-mode transport row
                    transportRow
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 18)

                    TRule()

                    // Input selector
                    if let sources = accessory?.sourceList, !sources.isEmpty {
                        TSectionHead(title: "Input")
                        inputSelector(sources: sources)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.bottom, 18)
                        TRule()
                    }

                    // Brightness
                    TSectionHead(title: "Brightness")
                    brightnessScale
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 22)

                    TRule()

                    // Color tone
                    TSectionHead(title: "Color Tone")
                    colorToneScale
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 22)

                    TRule()

                    // Stats strip
                    TSectionHead(title: "Current State")
                    HStack(spacing: 18) {
                        statCell(label: "Source", value: accessory?.currentSource ?? "—")
                        statCell(label: "Volume", value: accessory.flatMap { $0.volumePercent.map { "\($0)%" } } ?? "—")
                        statCell(label: "Muted", value: accessory?.isMuted == true ? "Yes" : "No")
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)

                    TRule()

                    // Destructive zone
                    Button {
                        // Placeholder — Frame TVs don't expose a reset via HA media_player.
                        // Leaving the affordance for future when we add a companion service.
                    } label: {
                        Text("Reset Frame")
                            .font(T3.inter(14, weight: .medium))
                            .foregroundStyle(T3.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let acc = accessory {
                brightness = acc.brightness ?? 0.7
            }
        }
    }

    // MARK: - Hero panel

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(heroTitle)
                        .font(T3.inter(18, weight: .bold))
                        .foregroundStyle(T3.ink)
                        .lineLimit(2)
                    Text(heroSubtitle)
                        .font(T3.inter(14, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(1)
                }
                Spacer()
                T3IconImage(systemName: heroIcon)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(T3.ink)
            }

            TLabel(text: "NEXT CHANGE · 10 MIN")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            Rectangle()
                .fill(T3.panel)
                .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
        )
        .padding(.top, 12)
    }

    private var heroTitle: String {
        if let np = accessory?.nowPlaying, let title = np.title { return title }
        if isArtMode { return "Starry Night Over the Rhône" }
        if isOn { return accessory?.currentSource ?? "Now Playing" }
        return "Art Mode Idle"
    }

    private var heroSubtitle: String {
        if let np = accessory?.nowPlaying, let artist = np.artist { return artist }
        if isArtMode { return "Vincent van Gogh · 1888" }
        if isOn { return "Live input" }
        return "Ambient artwork paused"
    }

    private var heroIcon: String {
        if isArtMode { return "image" }
        if isOn { return "monitor" }
        return "image"
    }

    // MARK: - Transport

    private var transportRow: some View {
        HStack(spacing: 1) {
            transportButton(icon: isOn ? "pause" : "play", label: "POWER") {
                Task { try? await registry.execute(.setPower(!isOn), on: accessoryID) }
            }
            transportButton(icon: "chevron.left", label: "PREV") {
                // Frame TVs step art via source change — cycle source list backward if present
                cycleArt(forward: false)
            }
            transportButton(icon: "chevron.right", label: "NEXT") {
                cycleArt(forward: true)
            }
        }
    }

    private func transportButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                T3IconImage(systemName: icon)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                Text(label)
                    .font(T3.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(T3.sub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(T3.panel)
            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func cycleArt(forward: Bool) {
        guard let sources = accessory?.sourceList, !sources.isEmpty else { return }
        let current = accessory?.currentSource ?? sources.first!
        guard let idx = sources.firstIndex(of: current) else { return }
        let next = forward
            ? sources[(idx + 1) % sources.count]
            : sources[(idx - 1 + sources.count) % sources.count]
        Task { try? await registry.execute(.selectSource(next), on: accessoryID) }
    }

    // MARK: - Input selector

    private func inputSelector(sources: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sources, id: \.self) { source in
                    Button {
                        Task { try? await registry.execute(.selectSource(source), on: accessoryID) }
                    } label: {
                        Text(source)
                            .font(T3.inter(13, weight: .medium))
                            .foregroundStyle(source == accessory?.currentSource ? T3.page : T3.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Rectangle()
                                    .fill(source == accessory?.currentSource ? T3.ink : T3.panel)
                                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Scales

    private var brightnessScale: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<41, id: \.self) { i in
                        let f = Double(i) / 40.0
                        let major = i % 5 == 0
                        Rectangle()
                            .fill(f <= brightness ? T3.ink : T3.rule)
                            .frame(width: 1, height: major ? 14 : 7)
                            .position(x: f * geo.size.width, y: major ? 7 : 3.5)
                    }
                    TDot(size: 10).position(x: brightness * geo.size.width, y: 22)
                }
                .frame(width: geo.size.width, height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let v = max(0, min(1, value.location.x / geo.size.width))
                            brightness = v
                            let bucket = Int((v * 10).rounded(.down))
                            if bucket != lastBrightnessBucket {
                                lastBrightnessBucket = bucket
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            }
                        }
                        .onEnded { _ in
                            Task { try? await registry.execute(.setBrightness(brightness), on: accessoryID) }
                        }
                )
            }
            .frame(height: 28)
            HStack { TLabel(text: "0"); Spacer(); TLabel(text: "50"); Spacer(); TLabel(text: "100") }
        }
    }

    private var colorToneScale: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<41, id: \.self) { i in
                        let f = Double(i) / 40.0
                        let major = i % 5 == 0
                        Rectangle()
                            .fill(f <= colorTone ? T3.ink : T3.rule)
                            .frame(width: 1, height: major ? 14 : 7)
                            .position(x: f * geo.size.width, y: major ? 7 : 3.5)
                    }
                    TDot(size: 10).position(x: colorTone * geo.size.width, y: 22)
                }
                .frame(width: geo.size.width, height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            colorTone = max(0, min(1, value.location.x / geo.size.width))
                        }
                )
            }
            .frame(height: 28)
            HStack { TLabel(text: "Warm"); Spacer(); TLabel(text: "Neutral"); Spacer(); TLabel(text: "Cool") }
        }
    }

    // MARK: - Stat cell

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

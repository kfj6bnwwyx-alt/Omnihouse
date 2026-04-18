//
//  T3CameraDetailView.swift
//  house connect
//
//  T3/Swiss camera detail — replaces legacy CameraDetailView. Pencil
//  node `iHJwa`. Layout:
//    • T3 masthead with live rec dot + running clock
//    • Title row with device name + LIVE orange pill
//    • Dark feed panel with corner brackets, motion overlay, timestamp,
//      resolution metadata caption
//    • Today's timeline: hairline track with event dots (today's
//      motion/package events as orange dots, earlier as sub grey)
//    • Control row: snapshot / talk / siren circle buttons + armed state
//    • Recent clips: hairline rows with thumbnail + label + time
//

import SwiftUI
import Combine

struct T3CameraDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    @State private var cameraController = CameraController()
    @State private var isArmed = true
    @State private var isTalking = false
    @State private var now = Date()

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "—" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "—"
    }

    private var providerLabel: String {
        accessoryID.provider.displayLabel.uppercased()
    }

    private var clockString: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: now)
    }

    private var stampString: String {
        let df = DateFormatter()
        df.dateFormat = "d MMM · HH:mm:ss"
        return df.string(from: now).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                title
                feedPanel
                timelineSection
                controlsSection
                recentClipsSection
                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .onReceive(clockTimer) { now = $0 }
        .onAppear { cameraController.attach(accessoryID: accessoryID, registry: registry) }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack {
            TLabel(text: "‹ " + roomName.uppercased())
            Spacer()
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(red: 0.88, green: 0.20, blue: 0.18))
                    .frame(width: 6, height: 6)
                TLabel(text: "REC  ·  \(clockString)")
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 8)
    }

    // MARK: - Title

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 12) {
                Text(accessory?.name ?? "Camera")
                    .font(T3.inter(30, weight: .medium))
                    .tracking(-0.6)
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(T3.page)
                        .frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(T3.mono(9))
                        .tracking(1.5)
                        .foregroundStyle(T3.page)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(T3.accent)
                .padding(.bottom, 6)
            }

            TLabel(text: "\(providerLabel)  ·  \(roomName.uppercased())")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    // MARK: - Feed

    private var feedPanel: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Dark feed background
                Rectangle().fill(Color(red: 0.09, green: 0.09, blue: 0.08))

                // Corner brackets
                bracket(at: .topLeading, width: geo.size.width)
                bracket(at: .topTrailing, width: geo.size.width)
                bracket(at: .bottomLeading, width: geo.size.width)
                bracket(at: .bottomTrailing, width: geo.size.width)

                // Technical caption top-left
                Text("\(providerLabel)  ·  H.265  ·  2.8MP")
                    .font(T3.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(T3.page.opacity(0.7))
                    .padding(.top, 30)
                    .padding(.leading, 24)

                // Motion box + label in center-ish
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOTION")
                        .font(T3.mono(9))
                        .tracking(1.5)
                        .foregroundStyle(T3.accent)
                    Rectangle()
                        .stroke(T3.accent, lineWidth: 1)
                        .frame(width: 96, height: 54)
                }
                .position(x: geo.size.width / 2, y: 150)

                // Labels bottom-left + bottom-right
                HStack {
                    Text((accessory?.name ?? "CAMERA").uppercased())
                        .font(T3.mono(9))
                        .tracking(1.5)
                        .foregroundStyle(T3.page.opacity(0.7))
                    Spacer()
                    Text(stampString)
                        .font(T3.mono(9))
                        .tracking(1.4)
                        .foregroundStyle(T3.page.opacity(0.7))
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .clipped()
        }
        .frame(height: 280)
    }

    private func bracket(at corner: Alignment, width: CGFloat) -> some View {
        let size: CGFloat = 20
        let thickness: CGFloat = 1
        let inset: CGFloat = 16
        let color = T3.page

        let hBar = Rectangle().fill(color).frame(width: size, height: thickness)
        let vBar = Rectangle().fill(color).frame(width: thickness, height: size)

        return ZStack(alignment: corner) {
            Color.clear
            VStack(spacing: 0) {
                if corner == .topLeading || corner == .topTrailing {
                    HStack { hBar; Spacer() }
                }
                HStack {
                    if corner == .topLeading || corner == .bottomLeading {
                        vBar; Spacer()
                    } else {
                        Spacer(); vBar
                    }
                }
                if corner == .bottomLeading || corner == .bottomTrailing {
                    HStack { hBar; Spacer() }
                }
            }
            .padding(inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner)
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                Text("Today")
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                Spacer()
                TLabel(text: "4 EVENTS")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(T3.rule)
                        .frame(height: 1)
                        .offset(y: 6)
                    ForEach(Array([0.1, 0.37, 0.63, 0.87].enumerated()), id: \.offset) { i, pct in
                        Circle()
                            .fill(i > 1 ? T3.accent : T3.sub)
                            .frame(width: 7, height: 7)
                            .offset(x: pct * geo.size.width - 3.5, y: 3)
                    }
                }
            }
            .frame(height: 14)

            HStack {
                TLabel(text: "00:00")
                Spacer()
                Text(clockString)
                    .font(T3.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(T3.ink)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 0) {
            HStack {
                controlButton(label: "SNAP", filled: false) {
                    cameraController.takeSnapshot()
                }
                Spacer()
                controlButton(label: "TALK", filled: isTalking) {
                    cameraController.toggleMicrophone()
                    isTalking.toggle()
                }
                Spacer()
                controlButton(label: "SIREN", filled: false) { }
                Spacer()
                controlButton(label: isArmed ? "ARMED" : "ARM", filled: isArmed) {
                    isArmed.toggle()
                }
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) { TRule() }
        }
    }

    private func controlButton(label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(filled ? T3.ink : T3.page)
                    .overlay(Circle().stroke(T3.ink, lineWidth: 1))
                    .frame(width: 42, height: 42)
                Text(label)
                    .font(T3.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(T3.ink)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent clips

    private var recentClipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                Text("Recent clips")
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                Spacer()
                TLabel(text: "04")
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)

            clipRow(title: "Motion · porch", meta: "14:22  ·  00:18", badge: "·")
            clipRow(title: "Package delivered", meta: "13:10  ·  00:42", badge: "NEW")
            clipRow(title: "Person · driveway", meta: "08:47  ·  00:09", badge: "·")
        }
    }

    private func clipRow(title: String, meta: String, badge: String) -> some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(Color(red: 0.09, green: 0.09, blue: 0.08))
                .frame(width: 56, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(T3.inter(14, weight: .regular))
                    .foregroundStyle(T3.ink)
                TLabel(text: meta)
            }
            Spacer()
            if badge == "NEW" {
                Text("NEW")
                    .font(T3.mono(9))
                    .tracking(1.5)
                    .foregroundStyle(T3.accent)
            } else if badge != "·" {
                Text(badge)
                    .font(T3.mono(9))
                    .tracking(1.5)
                    .foregroundStyle(T3.sub)
            } else {
                Circle().fill(T3.accent).frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
    }
}

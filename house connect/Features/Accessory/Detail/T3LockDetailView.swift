//
//  T3LockDetailView.swift
//  house connect
//
//  T3/Swiss lock detail — 220px circular toggle button,
//  stats strip, recent access log.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3LockDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isLocked: Bool = true
    @State private var holdProgress: Double = 0
    @State private var isHolding: Bool = false
    @State private var commitFlash: Bool = false
    @State private var holdTimer: Timer?
    @State private var toast: Toast?
    private let holdDuration: TimeInterval = T3.LongPress.light

    // Access log
    @State private var accessLog: [HomeAssistantProvider.HALockHistoryPoint] = []
    @State private var isLoadingLog: Bool = false
    @State private var logError: String?

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "Room" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "Room"
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: roomName,
                        rightLabel: accessory?.id.provider.displayLabel.uppercased(),
                        onBack: { dismiss() }
                    )

                    // Eyebrow + name
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            TDot(size: 8, color: isLocked ? T3.accent : T3.sub)
                                .accessibilityHidden(true)
                            TLabel(text: isLocked ? "Secured" : "Unlocked")
                        }

                        Text(accessory?.name ?? "Lock")
                            .font(T3.inter(42, weight: .medium))
                            .tracking(-1.4)
                            .foregroundStyle(T3.ink)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)
                    .padding(.bottom, 24)

                    // Centered circular button
                    HStack {
                        Spacer()
                        lockCircle
                        Spacer()
                    }
                    .padding(.bottom, 30)

                    TRule()

                    // Stats strip. Battery renders with a low-battery
                    // visual warning: <20% swaps to T3.danger tint and
                    // appends a small "Low" label so users notice
                    // before the lock actually dies.
                    HStack(spacing: 18) {
                        batteryStatCell(percent: batteryPercent)
                        statCell(
                            label: "Events",
                            value: isLoadingLog ? "…" : "\(accessLog.count)"
                        )
                        statCell(
                            label: "Provider",
                            value: accessoryID.provider.displayLabel
                        )
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)

                    TRule()

                    // Recent access
                    TSectionHead(
                        title: "Recent access",
                        count: isLoadingLog ? "…" : "\(accessLog.count)"
                    )

                    if isLoadingLog {
                        // Shimmer skeleton while fetching
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 14) {
                                Rectangle()
                                    .fill(T3.rule)
                                    .frame(width: 50, height: 11)
                                    .shimmering()
                                VStack(alignment: .leading, spacing: 6) {
                                    Rectangle()
                                        .fill(T3.rule)
                                        .frame(width: 80, height: 11)
                                        .shimmering()
                                    Rectangle()
                                        .fill(T3.rule)
                                        .frame(width: 120, height: 9)
                                        .shimmering()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 12)
                            .overlay(alignment: .top) { TRule() }
                        }
                    } else if let err = logError {
                        HStack(spacing: 10) {
                            T3IconImage(systemName: "exclamationmark.triangle")
                                .frame(width: 16, height: 16)
                                .foregroundStyle(T3.danger)
                            Text(err)
                                .font(T3.inter(12, weight: .regular))
                                .foregroundStyle(T3.sub)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { TRule() }
                    } else if accessLog.isEmpty {
                        Text("No access events in the last 24 hours")
                            .font(T3.inter(12, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 16)
                            .overlay(alignment: .top) { TRule() }
                    } else {
                        ForEach(Array(accessLog.reversed().enumerated()), id: \.offset) { i, point in
                            lockLogRow(point: point, isLast: i == accessLog.count - 1)
                        }
                    }

                    TSectionHead(title: "Device")
                    RemoveDeviceSection(accessoryID: accessoryID)

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toast($toast, duration: 4)
        .onAppear { syncLockState() }
        .onChange(of: accessory?.isOn) { syncLockState() }
        .task {
            await loadLockHistory()
        }
    }

    private func syncLockState() {
        // isOn==false → locked, isOn==true → unlocked (HA convention)
        // Guard against overwriting optimistic UI while the user is mid-hold.
        guard !isHolding else { return }
        isLocked = !(accessory?.isOn ?? true)
    }

    // MARK: - Lock Circle

    private var lockCircle: some View {
        ZStack {
            // Base circle
            Circle()
                .fill(commitFlash ? T3.accent : (isLocked ? T3.panel : T3.ink))
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .stroke(isLocked ? T3.ink : .clear, lineWidth: 1)
                )

            // Long-press progress ring (only when locked + holding)
            if isLocked {
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(T3.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: holdProgress)
            }

            VStack(spacing: 8) {
                T3IconImage(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .frame(width: 54, height: 54)
                    .foregroundStyle(commitFlash ? T3.page : (isLocked ? T3.ink : T3.accent))

                if isLocked {
                    Text("Hold to unlock")
                        .font(T3.mono(10))
                        .foregroundStyle(commitFlash ? T3.page : T3.sub)
                        .tracking(1)
                } else {
                    Text("Tap to lock")
                        .font(T3.mono(10))
                        .foregroundStyle(commitFlash ? T3.page : T3.page)
                        .tracking(1)
                }
            }
        }
        .contentShape(Circle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isLocked ? "Lock, secured" : "Lock, unlocked")
        .accessibilityHint(isLocked ? "Hold to unlock" : "Double tap to lock")
        // Tap to lock (when unlocked)
        .onTapGesture {
            guard !isLocked else { return }
            commitLock()
        }
        // Long-press to unlock (when locked)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: holdDuration)
                .onChanged { _ in
                    guard isLocked, !isHolding else { return }
                    beginHold()
                }
                .onEnded { _ in
                    guard isLocked else { return }
                    commitUnlock()
                }
        )
        // Abort hold on drag-away / release without completion
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if isHolding && holdProgress < 1.0 {
                        cancelHold()
                    }
                }
        )
    }

    private func beginHold() {
        isHolding = true
        holdProgress = 0
        holdTimer?.invalidate()
        let start = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(start)
            let p = min(1.0, elapsed / holdDuration)
            holdProgress = p
            if p >= 1.0 {
                t.invalidate()
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            holdProgress = 0
        }
    }

    // Unlock flow — security-relevant. Previously fired a medium haptic
    // and animated the UI to the "unlocked" state before awaiting the
    // provider command, then `try? await`-swallowed any failure. That
    // meant a failed unlock looked identical to a successful one.
    //
    // Fix: snapshot the previous state, animate the optimistic commit
    // flash, dispatch the command via T3ActionFeedback. On success the
    // primitive fires a .medium haptic (confirming actual unlock). On
    // failure it fires a warning haptic, invokes the revert closure to
    // snap isLocked back to true, and surfaces a toast so the user
    // actually sees that the unlock didn't happen.
    private func commitUnlock() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 1.0

        let previousIsLocked = isLocked

        // Flash orange, then settle to unlocked (ink) — optimistic UI
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            commitFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                commitFlash = false
                isLocked = false
                holdProgress = 0
            }
            Task { @MainActor in
                await T3ActionFeedback.perform(
                    action: { try await registry.execute(.setPower(true), on: accessoryID) },
                    onFailure: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            isLocked = previousIsLocked
                        }
                    },
                    successHaptic: .medium,
                    toast: { toast = .error("Couldn't unlock — try again") },
                    errorDescription: "Lock unlock"
                )
            }
        }
    }

    // Lock flow — same pattern, lower stakes. Revert toggles isLocked
    // back to false on failure so the UI doesn't lie about securing
    // the door when the command failed.
    private func commitLock() {
        let previousIsLocked = isLocked

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            commitFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                commitFlash = false
                isLocked = true
            }
            Task { @MainActor in
                await T3ActionFeedback.perform(
                    action: { try await registry.execute(.setPower(false), on: accessoryID) },
                    onFailure: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            isLocked = previousIsLocked
                        }
                    },
                    successHaptic: .light,
                    toast: { toast = .error("Couldn't lock — try again") },
                    errorDescription: "Lock lock"
                )
            }
        }
    }

    private var batteryPercent: Int? { accessory?.batteryLevel }

    // Battery stat cell with low-battery visual warning.
    //   • nil:    "—" (no battery data from provider)
    //   • <20%:  danger tint + "LOW" chip
    //   • 20–49%: T3.sub styling (de-emphasized)
    //   • >=50%:  standard T3.ink styling.
    @ViewBuilder
    private func batteryStatCell(percent: Int?) -> some View {
        let isLow = (percent ?? 100) < 20
        let isMedium = (percent ?? 100) < 50 && !isLow

        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: "Battery")
            HStack(spacing: 6) {
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(T3.inter(16, weight: .medium))
                    .foregroundStyle(isLow ? T3.danger : (isMedium ? T3.sub : T3.ink))
                if isLow {
                    Text("LOW")
                        .font(T3.mono(9))
                        .tracking(1.4)
                        .foregroundStyle(T3.danger)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .overlay(
                            Rectangle().stroke(T3.danger, lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percent == nil ? "Battery unknown" : (isLow
                            ? "Battery \(percent!) percent, low"
                            : "Battery \(percent!) percent"))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Lock history

    private func loadLockHistory() async {
        guard let haProvider = registry.providers
            .first(where: { $0.id == .homeAssistant }) as? HomeAssistantProvider else {
            return
        }
        let entityID = accessoryID.nativeID
        isLoadingLog = true
        logError = nil
        do {
            let points = try await haProvider.fetchLockHistory(
                entityID: entityID,
                hoursBack: 24
            )
            accessLog = points
        } catch {
            logError = error.localizedDescription
        }
        isLoadingLog = false
    }

    @ViewBuilder
    private func lockLogRow(
        point: HomeAssistantProvider.HALockHistoryPoint,
        isLast: Bool
    ) -> some View {
        let isLocked = point.state == "locked"
        let isJammed = point.state == "jammed"
        let action: String = isJammed ? "Jammed" : (isLocked ? "Locked" : "Unlocked")
        let who: String = {
            if let cb = point.changedBy, !cb.trimmingCharacters(in: .whitespaces).isEmpty {
                return cb.uppercased()
            }
            return "HOME ASSISTANT"
        }()
        let timeStr: String = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: point.timestamp)
        }()
        let iconName: String = isJammed ? "exclamationmark.triangle" : (isLocked ? "lock.fill" : "lock.open.fill")
        let iconColor: Color = isJammed ? T3.danger : T3.sub

        HStack(spacing: 14) {
            Text(timeStr)
                .font(T3.mono(11))
                .foregroundStyle(T3.sub)
                .monospacedDigit()
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(action)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(isJammed ? T3.danger : T3.ink)
                Text(who)
                    .font(T3.mono(10))
                    .foregroundStyle(T3.sub)
                    .tracking(0.8)
            }

            Spacer()

            T3IconImage(systemName: iconName)
                .frame(width: 14, height: 14)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) {
            if isLast { TRule() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(timeStr), \(action) by \(who)")
    }
}

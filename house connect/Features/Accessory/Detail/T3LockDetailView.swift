//
//  T3LockDetailView.swift
//  house connect
//
//  T3/Swiss lock detail — 220px circular toggle button,
//  stats strip, recent access log.
//

import SwiftUI

struct T3LockDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isLocked: Bool = true

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: "Room",
                        rightLabel: accessory?.id.provider.displayLabel.uppercased(),
                        onBack: { dismiss() }
                    )

                    // Eyebrow + name
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            TDot(size: 8, color: isLocked ? T3.accent : T3.sub)
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
                        Button {
                            withAnimation(.linear(duration: 0.15)) {
                                isLocked.toggle()
                            }
                            Task {
                                try? await registry.execute(.setPower(!isLocked), on: accessoryID)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isLocked ? T3.panel : T3.ink)
                                    .frame(width: 220, height: 220)
                                    .overlay(
                                        Circle()
                                            .stroke(isLocked ? T3.ink : .clear, lineWidth: 1)
                                    )

                                VStack(spacing: 8) {
                                    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                        .font(.system(size: 54, weight: .light))
                                        .foregroundStyle(isLocked ? T3.ink : T3.accent)

                                    if !isLocked {
                                        Text("Tap to lock")
                                            .font(T3.mono(10))
                                            .foregroundStyle(T3.page)
                                            .tracking(1)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.bottom, 30)

                    TRule()

                    // Stats strip
                    HStack(spacing: 18) {
                        statCell(label: "Battery", value: "87%")
                        statCell(label: "Signal", value: "Strong")
                        statCell(label: "Firmware", value: "2.1.4")
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)

                    TRule()

                    // Recent access
                    TSectionHead(title: "Recent access", count: "Today")

                    ForEach(Array(recentAccess.enumerated()), id: \.offset) { i, entry in
                        HStack(spacing: 14) {
                            Text(entry.time)
                                .font(T3.mono(11))
                                .foregroundStyle(T3.sub)
                                .monospacedDigit()
                                .frame(width: 60, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.action)
                                    .font(T3.inter(14, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                Text(entry.who)
                                    .font(T3.mono(10))
                                    .foregroundStyle(T3.sub)
                                    .tracking(0.8)
                            }

                            Spacer()

                            Image(systemName: entry.locked ? "lock.fill" : "checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(T3.sub)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) {
                            if i == recentAccess.count - 1 { TRule() }
                        }
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TLabel(text: label)
            Text(value)
                .font(T3.inter(16, weight: .medium))
                .foregroundStyle(T3.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentAccess: [(time: String, action: String, who: String, locked: Bool)] {
        [
            ("09:38", "Locked", "ALEX · HOMEKIT", true),
            ("08:14", "Unlocked", "ALEX · HOMEKIT", false),
            ("07:00", "Locked", "SCENE: MORNING", true),
            ("23:04", "Locked", "SCENE: GOODNIGHT", true),
        ]
    }
}

//
//  T3SceneRunResultSheet.swift
//  house connect
//
//  Detail sheet shown after a scene run that had at least one failure.
//  Lists every action's device + success/failure status + failure reason,
//  and offers a "Retry failed" button that re-runs only the failed actions
//  via SceneRunner.retryFailed(from:previousResult:).
//
//  T3 Swiss aesthetic: monochrome ink/sub/rule, hairline dividers,
//  orange accent reserved for the primary retry button.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct T3SceneRunResultSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    let scene: HCScene
    /// The most recent run result. Mutates on "Retry failed" so the sheet
    /// reflects the latest attempt without closing.
    @State var result: SceneRunResult
    @State private var isRetrying: Bool = false

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                TTitle(
                    title: scene.name + ".",
                    subtitle: "\(result.succeeded) of \(result.total) succeeded"
                )

                TSectionHead(title: "Devices", count: String(format: "%02d", result.total))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                            deviceRow(row)
                                .overlay(alignment: .top) { TRule() }
                                .overlay(alignment: .bottom) {
                                    if i == rows.count - 1 { TRule() }
                                }
                        }
                        Spacer(minLength: 120)
                    }
                }

                retryBar
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                TLabel(text: "Close", color: T3.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            TLabel(
                text: result.isFullSuccess ? "ALL OK" : result.isCompleteFailure ? "ALL FAILED" : "PARTIAL"
            )
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 8)
    }

    // MARK: - Rows model

    private struct Row: Hashable {
        let actionID: UUID
        let deviceName: String
        let success: Bool
        let errorMessage: String?
    }

    /// Build per-action rows by joining the scene's actions with the
    /// failures map. Accessory display name comes from the provider
    /// registry, falling back to the raw ID when the accessory has
    /// been removed since the run.
    private var rows: [Row] {
        let failureByAction: [UUID: SceneRunResult.Failure] = Dictionary(
            uniqueKeysWithValues: result.failures.map { ($0.actionID, $0) }
        )
        return scene.actions.map { action in
            let name = registry.allAccessories
                .first(where: { $0.id == action.accessoryID })?.name
                ?? action.accessoryID.nativeID
            if let failure = failureByAction[action.id] {
                return Row(
                    actionID: action.id,
                    deviceName: name,
                    success: false,
                    errorMessage: failure.message
                )
            } else {
                return Row(
                    actionID: action.id,
                    deviceName: name,
                    success: true,
                    errorMessage: nil
                )
            }
        }
    }

    // MARK: - Device row

    private func deviceRow(_ row: Row) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Status glyph
            T3IconImage(systemName: row.success ? "checkmark" : "xmark")
                .frame(width: 14, height: 14)
                .foregroundStyle(row.success ? T3.ok : T3.danger)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.deviceName)
                    .font(T3.inter(15, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(T3.ink)
                    .lineLimit(2)

                if let message = row.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(T3.inter(12, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else if row.success {
                    TLabel(text: "OK")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
    }

    // MARK: - Retry bar

    @ViewBuilder
    private var retryBar: some View {
        let failedCount = result.failures.count
        VStack(spacing: 0) {
            TRule()
            Button {
                retryFailed()
            } label: {
                HStack {
                    Spacer()
                    if isRetrying {
                        Text("RETRYING...")
                            .font(T3.mono(11))
                            .tracking(1)
                            .foregroundStyle(T3.sub)
                    } else if failedCount == 0 {
                        Text("NOTHING TO RETRY")
                            .font(T3.mono(11))
                            .tracking(1)
                            .foregroundStyle(T3.sub)
                    } else {
                        Text(String(format: "RETRY FAILED · %02d", failedCount))
                            .font(T3.mono(11))
                            .tracking(1)
                            .foregroundStyle(T3.accent)
                    }
                    Spacer()
                }
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRetrying || failedCount == 0)
        }
    }

    // MARK: - Retry action

    private func retryFailed() {
        guard !isRetrying, !result.failures.isEmpty else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        isRetrying = true
        let previous = result
        Task {
            let retryResult = await SceneRunner(registry: registry)
                .retryFailed(from: scene, previousResult: previous)
            await MainActor.run {
                // `retryFailed` re-runs every previously-failed action, so
                // the new failure set is exactly `retryResult.failures`.
                // Previously-succeeded actions are untouched — we carry
                // the original `total` and compute `succeeded` from the
                // merged failure count.
                let merged = retryResult.failures
                result = SceneRunResult(
                    sceneID: scene.id,
                    total: previous.total,
                    succeeded: previous.total - merged.count,
                    failures: merged
                )

                #if canImport(UIKit)
                if merged.isEmpty {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                #endif
                isRetrying = false
            }
        }
    }
}

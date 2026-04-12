//
//  SceneRunner.swift
//  house connect
//
//  Fires all of a scene's actions through the ProviderRegistry.
//
//  Concurrency strategy:
//  ---------------------
//  Actions run in PARALLEL via a TaskGroup. Most scenes hit multiple
//  providers at once (HomeKit lights + Sonos pause + SmartThings plug),
//  and each provider call can take ~100–500ms. Serial would feel laggy.
//  We collect per-action errors and surface them as a single struct, so
//  a failing SmartThings device doesn't silently prevent the HomeKit
//  light from turning on.
//
//  This type is NOT @Observable. It's a stateless helper — the UI owns
//  the `isRunning` flag for a given scene, not the runner.
//

import Foundation

@MainActor
struct SceneRunner {
    let registry: ProviderRegistry

    /// Runs every action in `scene` in parallel. Returns a result containing
    /// counts and any per-action failures. Never throws — the caller decides
    /// how to present partial success.
    func run(_ scene: HCScene) async -> SceneRunResult {
        guard !scene.actions.isEmpty else {
            return SceneRunResult(sceneID: scene.id,
                                  total: 0,
                                  succeeded: 0,
                                  failures: [])
        }

        var failures: [SceneRunResult.Failure] = []

        await withTaskGroup(of: SceneRunResult.Failure?.self) { group in
            for action in scene.actions {
                group.addTask { @MainActor in
                    do {
                        try await registry.execute(action.command,
                                                   on: action.accessoryID)
                        return nil
                    } catch {
                        return SceneRunResult.Failure(
                            actionID: action.id,
                            accessoryID: action.accessoryID,
                            message: (error as? LocalizedError)?.errorDescription
                                ?? error.localizedDescription
                        )
                    }
                }
            }
            for await failure in group {
                if let failure { failures.append(failure) }
            }
        }

        return SceneRunResult(
            sceneID: scene.id,
            total: scene.actions.count,
            succeeded: scene.actions.count - failures.count,
            failures: failures
        )
    }
}

/// Outcome of running a scene — used by the UI to render a toast or an
/// inline error row after a tap.
struct SceneRunResult: Sendable {
    let sceneID: UUID
    let total: Int
    let succeeded: Int
    let failures: [Failure]

    var isFullSuccess: Bool { failures.isEmpty && total > 0 }
    var isCompleteFailure: Bool { succeeded == 0 && total > 0 }

    struct Failure: Sendable {
        let actionID: UUID
        let accessoryID: AccessoryID
        let message: String
    }
}

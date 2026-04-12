//
//  SceneStore.swift
//  house connect
//
//  Observable store holding all user-defined scenes. Persists to a JSON
//  file in the app's Application Support directory. SwiftUI observes the
//  store; edits call `save()` synchronously at the end so there's no
//  "did my edit actually land" ambiguity.
//
//  Why JSON on disk instead of SwiftData:
//  ---------------------------------------
//  We're only storing ~dozens of scenes, all user-authored, and we want
//  flat human-readable files for debugging and eventual backend sync. A
//  single atomic write per edit is simpler than a SwiftData container
//  + migrations we'd have to maintain. Revisit when we need
//  relationships (scenes referencing automations referencing triggers).
//
//  File location:
//    ~/Library/Application Support/house connect/scenes.json
//
//  Seeding:
//  --------
//  On first launch the store writes four starter scenes (Morning, Away,
//  Movie, Sleep) that match the Pencil design. They're empty — no actions
//  attached — so tapping them is a no-op until the user edits them. This
//  keeps the dashboard scene row populated immediately without us having
//  to fabricate behavior for devices we haven't seen yet.
//

import Foundation
import Observation

@MainActor
@Observable
final class SceneStore {
    private(set) var scenes: [HCScene] = []

    /// Last error from a save/load attempt. Surfaced by the UI so failures
    /// aren't silent. Cleared on the next successful op.
    private(set) var lastError: String?

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL? = nil) {
        // Default location: Application Support/<bundle>/scenes.json
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let fm = FileManager.default
            let base = (try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true))
                ?? fm.temporaryDirectory
            let appDir = base.appendingPathComponent("house connect", isDirectory: true)
            // Best-effort create; `write` below will retry.
            try? fm.createDirectory(at: appDir,
                                    withIntermediateDirectories: true)
            self.fileURL = appDir.appendingPathComponent("scenes.json")
        }

        load()
        if scenes.isEmpty {
            seedDefaults()
        }
    }

    // MARK: - CRUD

    func add(_ scene: HCScene) {
        scenes.append(scene)
        save()
    }

    func update(_ scene: HCScene) {
        guard let idx = scenes.firstIndex(where: { $0.id == scene.id }) else { return }
        scenes[idx] = scene
        save()
    }

    func remove(id: UUID) {
        scenes.removeAll { $0.id == id }
        save()
    }

    func scene(id: UUID) -> HCScene? {
        scenes.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([HCScene].self, from: data)
            self.scenes = decoded
            self.lastError = nil
        } catch {
            // Corrupt file — don't crash, surface the error, leave
            // scenes empty so seeding kicks in on first use.
            self.lastError = "Couldn't load scenes: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(scenes)
            try data.write(to: fileURL, options: .atomic)
            self.lastError = nil
        } catch {
            self.lastError = "Couldn't save scenes: \(error.localizedDescription)"
        }
    }

    /// First-run seed: writes the four Pencil-design scene tiles. Empty
    /// actions — user fills them in via SceneEditorView.
    private func seedDefaults() {
        scenes = [
            HCScene(name: "Morning", iconSystemName: "sun.max.fill"),
            HCScene(name: "Away", iconSystemName: "shield.fill"),
            HCScene(name: "Movie", iconSystemName: "tv.fill"),
            HCScene(name: "Sleep", iconSystemName: "moon.fill"),
        ]
        save()
    }
}

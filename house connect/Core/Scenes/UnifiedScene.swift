//
//  UnifiedScene.swift
//  house connect
//
//  Bridges local HCScene objects (user-created, cross-provider) and
//  Home Assistant scene entities into a single type the UI can render.
//  The dashboard and scenes list iterate `[UnifiedScene]` and dispatch
//  to the right execution path based on the source.
//
//  Why not replace HCScene entirely?
//  ---------------------------------
//  Local scenes may contain cross-provider actions that HA doesn't know
//  about (e.g. "dim HomeKit + pause Sonos + set SmartThings thermostat").
//  HA scenes only target devices HA manages. Both coexist until the user
//  migrates everything to HA, at which point local scenes can be removed.
//

import Foundation

/// A scene that the UI can render and execute regardless of origin.
struct UnifiedScene: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case local(UUID)          // HCScene.id
        case homeAssistant(String) // HAScene.entityID
    }

    let id: String
    let name: String
    let iconSystemName: String
    let source: Source

    /// Human-readable origin badge for the UI.
    var sourceBadge: String {
        switch source {
        case .local: return "Local"
        case .homeAssistant: return "HA"
        }
    }

    /// Create from a local HCScene.
    init(from scene: HCScene) {
        self.id = "local:\(scene.id.uuidString)"
        self.name = scene.name
        self.iconSystemName = scene.iconSystemName
        self.source = .local(scene.id)
    }

    /// Create from a Home Assistant scene entity.
    init(from haScene: HAScene) {
        self.id = "ha:\(haScene.entityID)"
        self.name = haScene.name
        // Map HA scene names to reasonable icons via keyword matching.
        self.iconSystemName = Self.guessIcon(for: haScene.name)
        self.source = .homeAssistant(haScene.entityID)
    }

    /// Best-effort icon guess from the scene name. HA scenes don't carry
    /// icons — we infer from keywords.
    private static func guessIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("morning") || lower.contains("wake") || lower.contains("sunrise") {
            return "sun.max.fill"
        }
        if lower.contains("night") || lower.contains("sleep") || lower.contains("bedtime") {
            return "moon.fill"
        }
        if lower.contains("movie") || lower.contains("theater") || lower.contains("cinema") {
            return "tv.fill"
        }
        if lower.contains("away") || lower.contains("leave") || lower.contains("vacation") {
            return "shield.fill"
        }
        if lower.contains("dinner") || lower.contains("cooking") || lower.contains("meal") {
            return "fork.knife"
        }
        if lower.contains("party") || lower.contains("music") || lower.contains("dance") {
            return "party.popper.fill"
        }
        if lower.contains("relax") || lower.contains("chill") || lower.contains("calm") {
            return "leaf.fill"
        }
        if lower.contains("bright") || lower.contains("all on") || lower.contains("full") {
            return "lightbulb.fill"
        }
        if lower.contains("off") || lower.contains("dark") {
            return "lightbulb.slash"
        }
        if lower.contains("reading") || lower.contains("study") || lower.contains("work") {
            return "book.fill"
        }
        // Default: generic scene icon
        return "sparkles"
    }
}

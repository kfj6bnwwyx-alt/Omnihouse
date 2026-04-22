//
//  Room.swift
//  house connect
//

import Foundation

struct Room: Identifiable, Hashable, Sendable, Codable {
    /// Globally unique within a provider (provider namespaces it).
    let id: String
    var name: String
    var homeID: String
    var provider: ProviderID
}

extension Room {
    /// SF Symbol inferred from the room name.
    var glyph: String {
        let lower = name.lowercased()
        if lower.contains("living") || lower.contains("family") || lower.contains("den") { return "sofa.fill" }
        if lower.contains("kitchen") { return "fork.knife" }
        if lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("entry") || lower.contains("door") || lower.contains("hall") { return "door.left.hand.open" }
        if lower.contains("bath") { return "shower.fill" }
        if lower.contains("office") || lower.contains("study") { return "desktopcomputer" }
        if lower.contains("garage") { return "car.fill" }
        return "square.grid.2x2"
    }
}

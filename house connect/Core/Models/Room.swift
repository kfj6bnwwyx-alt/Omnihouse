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

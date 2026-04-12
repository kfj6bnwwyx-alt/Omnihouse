//
//  Home.swift
//  house connect
//

import Foundation

struct Home: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var name: String
    var isPrimary: Bool
    var provider: ProviderID
}

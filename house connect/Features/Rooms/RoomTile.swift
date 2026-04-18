//
//  RoomTile.swift
//  house connect
//
//  Extracted from the deleted legacy `HomeDashboardView.swift` during
//  the T3 migration on 2026-04-18. Still used by `AllRoomsView`
//  (itself legacy-reachable — T3RoomsTabView is the live surface).
//  Will be deleted once `AllRoomsView` is either removed or ported.
//

import SwiftUI

struct RoomTile: View {
    let room: Room
    let deviceCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconChip(systemName: RoomIcon.systemName(for: room.name), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                    .lineLimit(1)
                Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s")")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(room.name), \(deviceCount) device\(deviceCount == 1 ? "" : "s")")
        .accessibilityHint("Double tap to view room")
        .accessibilityAddTraits(.isButton)
    }
}

/// Maps common room names to SF Symbols. Falls through to a generic
/// square icon if we don't recognize the name.
enum RoomIcon {
    static func systemName(for roomName: String) -> String {
        let n = roomName.lowercased()
        if n.contains("living") { return "sofa.fill" }
        if n.contains("bed") { return "bed.double.fill" }
        if n.contains("kitchen") { return "fork.knife" }
        if n.contains("office") { return "desktopcomputer" }
        if n.contains("bath") { return "shower.fill" }
        if n.contains("garage") { return "car.fill" }
        if n.contains("dining") { return "fork.knife.circle.fill" }
        if n.contains("garden") || n.contains("yard") { return "leaf.fill" }
        if n.contains("laundry") { return "washer.fill" }
        if n.contains("hall") || n.contains("entry") { return "door.left.hand.open" }
        return "square.grid.2x2.fill"
    }
}

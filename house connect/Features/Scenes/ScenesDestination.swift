//
//  ScenesDestination.swift
//  house connect
//
//  Navigation destination for the scenes flow. Extracted from the
//  deleted legacy `HomeDashboardView.swift` during the T3 migration on
//  2026-04-18. Still used by the legacy `ScenesListView`
//  (T3ScenesListView is the live surface). Can go when `ScenesListView`
//  is either removed or ported.
//

import Foundation

enum ScenesDestination: Hashable {
    case list
    case editor(sceneID: UUID?)
}

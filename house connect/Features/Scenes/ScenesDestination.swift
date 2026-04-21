//
//  ScenesDestination.swift
//  house connect
//
//  Navigation destination for the scenes flow. Extracted from the
//  deleted legacy `HomeDashboardView.swift` during the T3 migration on
//  2026-04-18. Used by T3ScenesListView and T3SceneEditorView.
//

import Foundation

enum ScenesDestination: Hashable {
    case list
    case editor(sceneID: UUID?)
}

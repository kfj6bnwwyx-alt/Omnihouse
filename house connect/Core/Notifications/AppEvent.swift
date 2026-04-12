//
//  AppEvent.swift
//  house connect
//
//  A single row in the Notifications Center (Pencil `mCjOM`). The center
//  is a chronological feed of everything interesting the app has noticed:
//  smoke detector fires, devices dropping offline, scenes running, new
//  devices discovered, automations succeeding, etc.
//
//  Why a homegrown model instead of UNNotificationRequest:
//  -------------------------------------------------------
//  Most of what we surface here isn't a system push — it's an in-app
//  observation. A device went offline during a poll; a scene ran from a
//  schedule; SmartThings published a new accessory. System notifications
//  are optional and opt-in; the in-app feed is always available. We keep
//  the two channels separate so one can grow without constraining the
//  other.
//
//  Persistence:
//  ------------
//  Ring-buffered in memory only. Events from 48 hours ago aren't useful
//  for a home dashboard, and persisting them costs more than it saves.
//  When the user kills and relaunches the app the list starts empty —
//  the store re-seeds itself as providers come online.
//

import Foundation

/// A single feed entry. Identified by a stable UUID so SwiftUI can
/// ForEach without row-jitter when new events stream in at the top.
struct AppEvent: Identifiable, Hashable {
    let id: UUID
    let kind: Kind
    /// Short headline, e.g. "Front door unlocked".
    let title: String
    /// Longer detail line, e.g. "by Morning scene" or "3 minutes ago".
    /// Optional — a single-line event just leaves it nil.
    let message: String?
    let timestamp: Date
    /// True while the user hasn't seen it yet. Used for the unread dot
    /// in the list and the badge count on the bell icon.
    var isUnread: Bool

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        message: String? = nil,
        timestamp: Date = Date(),
        isUnread: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isUnread = isUnread
    }

    /// Buckets drive the accent color and the SF Symbol shown on the
    /// left chip. Kept narrow on purpose — more kinds means more icons
    /// to design, not more code paths to maintain.
    enum Kind: String, Hashable {
        case alert       // smoke, leak, security — red
        case offline     // device dropped — amber
        case automation  // scene ran, schedule fired — blue
        case discovery   // new device published by a provider — green
        case info        // generic — muted

        var systemImage: String {
            switch self {
            case .alert:      "exclamationmark.triangle.fill"
            case .offline:    "wifi.slash"
            case .automation: "play.fill"
            case .discovery:  "sparkles"
            case .info:       "bell.fill"
            }
        }
    }
}

//
//  AppEventStore.swift
//  house connect
//
//  Central inbox for everything the Notifications Center (Pencil mCjOM)
//  displays. Observable so the bell badge and the list both update live.
//
//  Design notes:
//  -------------
//  - Ring-buffered at `maxEvents` items. Older entries are dropped
//    silently — the feed is for "what just happened", not an audit log.
//  - `unreadCount` is computed from the ring; callers never mutate a
//    counter directly, so the bell badge can't drift out of sync with
//    the list body.
//  - The store is deliberately simple — no categories, no filtering,
//    no grouping. Those belong in the view, not the model. Scenes,
//    providers, and the smoke alert controller all push flat events.
//  - First-run seed:
//      The feed starts empty. We DO NOT fabricate welcome messages —
//      they'd just accumulate real-unread noise on top of real events
//      and train the user to dismiss notifications reflexively. Phase
//      3c may revisit if onboarding needs a nudge.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppEventStore {
    /// Most recent first. Callers iterate this directly for the list.
    private(set) var events: [AppEvent] = []

    /// Ceiling for in-memory retention. 200 is enough for a day of heavy
    /// household traffic; beyond that older entries fall off silently.
    @ObservationIgnored let maxEvents = 200

    /// Convenience for the bell badge. Recomputed on every access;
    /// ~O(200) is fine and keeps this source-of-truth-free.
    var unreadCount: Int {
        events.reduce(0) { $0 + ($1.isUnread ? 1 : 0) }
    }

    // MARK: - Mutation

    /// Inserts a new event at the top of the feed and trims the tail
    /// down to `maxEvents`. Always marks the new row unread — callers
    /// who want otherwise can post then immediately markAllRead(), but
    /// in practice we treat every push as "you should look".
    func post(_ event: AppEvent) {
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }

    /// Convenience overload so callers don't have to spell out the
    /// whole AppEvent initializer for the common case.
    func post(
        kind: AppEvent.Kind,
        title: String,
        message: String? = nil
    ) {
        post(AppEvent(kind: kind, title: title, message: message))
    }

    /// Flip every row to read. Invoked when the user opens the
    /// Notifications Center — matches every mainstream inbox UX.
    func markAllRead() {
        guard unreadCount > 0 else { return }
        for idx in events.indices where events[idx].isUnread {
            events[idx].isUnread = false
        }
    }

    /// Clear everything. Reachable from the "Clear All" button at the
    /// top of the list. Not undoable — these are low-value ephemeral
    /// events, not mail you might need to recover.
    func clearAll() {
        events.removeAll()
    }
}

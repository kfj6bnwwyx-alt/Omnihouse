//
//  NotificationsCenterView.swift
//  house connect
//
//  Pencil mCjOM — chronological inbox of everything that's happened in
//  the app: smoke alerts, scenes running, devices dropping offline, new
//  discoveries. Pushed from the bell icon in the Home header.
//
//  Structure:
//  ----------
//  - Header row with a "Clear All" button (hidden when empty)
//  - A list of `EventRow`s grouped by day bucket: Today / Yesterday /
//    Earlier. Grouping is view-only; the store stays a flat array.
//  - Empty state mirrors the design-system empty state used elsewhere
//    so an empty inbox looks intentional rather than broken.
//
//  On appear we flip everything to read, which is the behavior every
//  mainstream mail/notification app uses. The user gets a single
//  "badge cleared" moment rather than per-row dismissal.
//

import SwiftUI

struct NotificationsCenterView: View {
    @Environment(AppEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if eventStore.events.isEmpty {
                    emptyState
                        .padding(.top, 48)
                } else {
                    ForEach(grouped, id: \.title) { section in
                        eventSection(section)
                    }
                }
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !eventStore.events.isEmpty {
                    Button("Clear All") {
                        eventStore.clearAll()
                    }
                    .tint(Theme.color.primary)
                }
            }
        }
        .onAppear {
            // Single "you've seen it" moment — matches Mail/Messages.
            eventStore.markAllRead()
        }
    }

    // MARK: - Grouping

    /// Tiny view-local DTO so the ForEach can key off a stable section
    /// title without leaking a Date range into the store.
    private struct Section {
        let title: String
        let events: [AppEvent]
    }

    private var grouped: [Section] {
        let cal = Calendar.current
        var today: [AppEvent] = []
        var yesterday: [AppEvent] = []
        var earlier: [AppEvent] = []
        for event in eventStore.events {
            if cal.isDateInToday(event.timestamp) {
                today.append(event)
            } else if cal.isDateInYesterday(event.timestamp) {
                yesterday.append(event)
            } else {
                earlier.append(event)
            }
        }
        var out: [Section] = []
        if !today.isEmpty { out.append(Section(title: "Today", events: today)) }
        if !yesterday.isEmpty { out.append(Section(title: "Yesterday", events: yesterday)) }
        if !earlier.isEmpty { out.append(Section(title: "Earlier", events: earlier)) }
        return out
    }

    private func eventSection(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(Theme.font.sectionHeader)
                .foregroundStyle(Theme.color.title)
                .padding(.top, 4)
            VStack(spacing: 10) {
                ForEach(section.events) { event in
                    EventRow(event: event)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            IconChip(systemName: "bell.slash.fill", size: 56)
            Text("No notifications")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)
            Text("Alerts, scene runs, and device changes will show up here as they happen.")
                .font(Theme.font.cardSubtitle)
                .foregroundStyle(Theme.color.subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

/// One row in the feed. Left chip carries the icon+tint for the Kind;
/// right side is title + message + timestamp. The unread dot is a
/// small blue pip on the top-right so it doesn't compete with the
/// message text for visual priority.
private struct EventRow: View {
    let event: AppEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconChip
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if event.isUnread {
                        Circle()
                            .fill(Theme.color.primary)
                            .frame(width: 8, height: 8)
                    }
                }
                if let message = event.message {
                    Text(message)
                        .font(Theme.font.cardSubtitle)
                        .foregroundStyle(Theme.color.subtitle)
                        .lineLimit(3)
                }
                Text(relativeTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hcCard()
    }

    private var iconChip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                .fill(tint.opacity(0.18))
                .frame(width: 44, height: 44)
            Image(systemName: event.kind.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    /// Accent color for the row. Pulled here so the store's Kind enum
    /// stays free of SwiftUI types.
    private var tint: Color {
        switch event.kind {
        case .alert:      return Color(red: 0.93, green: 0.29, blue: 0.27)
        case .offline:    return Color(red: 0.96, green: 0.69, blue: 0.23)
        case .automation: return Theme.color.primary
        case .discovery:  return Color(red: 0.33, green: 0.77, blue: 0.49)
        case .info:       return Theme.color.muted
        }
    }

    private var relativeTime: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: event.timestamp, relativeTo: Date())
    }
}

//
//  T3ActivityView.swift
//  house connect
//
//  T3/Swiss Activity log — today's event timeline.
//  Groups events by Today / Yesterday / Older.
//

import SwiftUI

struct T3ActivityView: View {
    @Environment(AppEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(label: String, events: [AppEvent])] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return [("Today", eventStore.events)]
        }

        let today = eventStore.events.filter { $0.timestamp >= startOfToday }
        let yesterday = eventStore.events.filter { $0.timestamp >= startOfYesterday && $0.timestamp < startOfToday }
        let older = eventStore.events.filter { $0.timestamp < startOfYesterday }

        var groups: [(label: String, events: [AppEvent])] = []
        if !today.isEmpty     { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !older.isEmpty     { groups.append(("Older", older)) }
        return groups
    }

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Home", onBack: { dismiss() })
                    TTitle(
                        title: "Activity.",
                        subtitle: "\(eventStore.events.count) events"
                    )

                    if eventStore.events.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.label) { group in
                            groupSection(label: group.label, events: group.events)
                        }

                        // Clear all
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            eventStore.clearAll()
                        } label: {
                            HStack {
                                T3IconImage(systemName: "trash")
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(T3.sub)
                                    .accessibilityHidden(true)
                                Text("Clear activity log")
                                    .font(T3.inter(13, weight: .regular))
                                    .foregroundStyle(T3.sub)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear activity log")
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.top, 16)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { eventStore.markAllRead() }
    }

    // MARK: - Group section

    @ViewBuilder
    private func groupSection(label: String, events: [AppEvent]) -> some View {
        TSectionHead(title: label, count: String(format: "%02d", events.count))

        ForEach(Array(events.enumerated()), id: \.element.id) { i, event in
            HStack(spacing: 14) {
                Text(event.timestamp.formatted(.dateTime.hour().minute()))
                    .font(T3.mono(11))
                    .foregroundStyle(T3.sub)
                    .monospacedDigit()
                    .frame(width: 56, alignment: .leading)

                T3IconImage(systemName: eventIcon(event.kind))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(T3.inter(14, weight: .medium))
                        .foregroundStyle(T3.ink)
                    if let msg = event.message {
                        Text(msg)
                            .font(T3.mono(10))
                            .foregroundStyle(T3.sub)
                            .tracking(0.6)
                    }
                }

                Spacer()

                if event.isUnread {
                    TDot(size: 5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, T3.screenPadding)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { TRule() }
            .overlay(alignment: .bottom) {
                if i == events.count - 1 { TRule() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(event.timestamp.formatted(.dateTime.hour().minute())), \(event.title)\(event.message.map { ", \($0)" } ?? "")")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            TLabel(text: "No activity yet")
            Text("Events will appear as you interact with your devices.")
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.sub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 48)
    }

    // MARK: - Icon

    private func eventIcon(_ kind: AppEvent.Kind) -> String {
        switch kind {
        case .automation: return "gearshape"
        case .alert:      return "exclamationmark.triangle"
        case .offline:    return "wifi.slash"
        case .discovery:  return "sparkles"
        case .info:       return "info.circle"
        }
    }
}

//
//  T3NotificationsView.swift
//  house connect
//
//  T3/Swiss notifications — event timeline, same pattern as T3ActivityView
//  but reached from the notification bell on Home.
//

import SwiftUI

struct T3NotificationsView: View {
    @Environment(AppEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with clear action
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                TLabel(text: "Home", color: T3.ink)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if !eventStore.events.isEmpty {
                            Button {
                                eventStore.markAllRead()
                            } label: {
                                TLabel(text: "Mark read", color: T3.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 8)

                    TTitle(
                        title: "Notifications.",
                        subtitle: eventStore.unreadCount > 0
                            ? "\(eventStore.unreadCount) unread"
                            : "All caught up"
                    )

                    if eventStore.events.isEmpty {
                        VStack(spacing: 12) {
                            TLabel(text: "No notifications")
                            Text("Events will appear as your devices change state.")
                                .font(.system(size: 13))
                                .foregroundStyle(T3.sub)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(Array(eventStore.events.prefix(30).enumerated()), id: \.element.id) { i, event in
                            HStack(spacing: 14) {
                                // Unread dot
                                if event.isUnread {
                                    TDot(size: 6)
                                } else {
                                    Color.clear.frame(width: 6, height: 6)
                                }

                                Text(event.timestamp.formatted(.dateTime.hour().minute()))
                                    .font(T3.mono(11))
                                    .foregroundStyle(T3.sub)
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(T3.inter(14, weight: .medium))
                                        .foregroundStyle(T3.ink)
                                    if let msg = event.message {
                                        TLabel(text: msg)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 12)
                            .overlay(alignment: .top) { TRule() }
                            .overlay(alignment: .bottom) {
                                if i == min(29, eventStore.events.count - 1) { TRule() }
                            }
                        }
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            eventStore.markAllRead()
        }
    }
}

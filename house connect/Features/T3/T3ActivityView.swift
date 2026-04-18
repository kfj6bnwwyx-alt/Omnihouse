//
//  T3ActivityView.swift
//  house connect
//
//  T3/Swiss Activity log — today's event timeline.
//

import SwiftUI

struct T3ActivityView: View {
    @Environment(AppEventStore.self) private var eventStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(backLabel: "Home", onBack: { dismiss() })
                    TTitle(title: "Activity.")

                    ForEach(Array(eventStore.events.prefix(20).enumerated()), id: \.element.id) { i, event in
                        HStack(spacing: 14) {
                            Text(event.timestamp.formatted(.dateTime.hour().minute()))
                                .font(T3.mono(11))
                                .foregroundStyle(T3.sub)
                                .monospacedDigit()
                                .frame(width: 56, alignment: .leading)

                            Image(systemName: eventIcon(event.kind))
                                .font(T3.inter(18, weight: .medium))
                                .foregroundStyle(T3.ink)
                                .frame(width: 28)

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
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) {
                            if i == min(19, eventStore.events.count - 1) { TRule() }
                        }
                    }

                    if eventStore.events.isEmpty {
                        VStack(spacing: 12) {
                            TLabel(text: "No activity yet")
                            Text("Events will appear as you interact with your devices.")
                                .font(T3.inter(13, weight: .regular))
                                .foregroundStyle(T3.sub)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func eventIcon(_ kind: AppEvent.Kind) -> String {
        switch kind {
        case .automation: return "gearshape"
        case .alert: return "exclamationmark.triangle"
        case .offline: return "wifi.slash"
        case .discovery: return "sparkles"
        case .info: return "info.circle"
        }
    }
}

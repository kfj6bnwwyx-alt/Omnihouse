//
//  T3ThermostatHistoryView.swift
//  house connect
//
//  Timeline of setpoint / mode / HVAC-action changes for a single
//  HA climate entity. Pulls from the provider's
//  `fetchThermostatHistory(entityID:hoursBack:)` REST-backed helper,
//  collapses consecutive identical rows, groups the remaining diffs
//  by hour, and renders them in the T3 aesthetic (cream page, ink
//  rules, mono labels).
//
//  No charts — just an events list. HA's recorder row cadence is
//  sparse enough that a diff list reads more cleanly than a line
//  graph, and it aligns with the "what changed and when?" question
//  users actually ask about their thermostat.
//

import SwiftUI

struct T3ThermostatHistoryView: View {
    let entityID: String
    let name: String

    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearance.tempUnit") private var tempUnit: String = "celsius"
    private var useFahrenheit: Bool { tempUnit == "fahrenheit" }

    /// Rolling window options. `hours` is what the fetch takes;
    /// `label` drives the segmented control caption.
    private enum Window: String, CaseIterable, Identifiable {
        case sixHours = "6H"
        case dayHours = "24H"
        case weekHours = "7D"

        var id: String { rawValue }

        var hours: Int {
            switch self {
            case .sixHours: return 6
            case .dayHours: return 24
            case .weekHours: return 24 * 7
            }
        }

        var subtitle: String {
            switch self {
            case .sixHours: return "Last 6 hours"
            case .dayHours: return "Last 24 hours"
            case .weekHours: return "Last 7 days"
            }
        }
    }

    @State private var window: Window = .dayHours
    @State private var events: [ThermostatHistoryEvent] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    THeader(
                        backLabel: "Thermostat",
                        rightLabel: "History",
                        onBack: { dismiss() }
                    )

                    TTitle(title: name, subtitle: window.subtitle)

                    windowPicker
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.bottom, 20)

                    TRule()

                    if isLoading {
                        loadingView
                    } else if let errorMessage {
                        errorView(errorMessage)
                    } else if events.isEmpty {
                        T3EmptyState(
                            iconSystemName: "clock",
                            title: "No changes recorded",
                            subtitle: "Home Assistant hasn't logged any setpoint or mode changes for this thermostat during this window."
                        )
                    } else {
                        eventsList
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: window) {
            await load()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    // MARK: - Window picker

    private var windowPicker: some View {
        HStack(spacing: 6) {
            ForEach(Window.allCases) { opt in
                Button {
                    window = opt
                } label: {
                    Text(opt.rawValue)
                        .font(T3.inter(12, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(window == opt ? T3.page : T3.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: T3.segmentCellRadius)
                                .fill(window == opt ? T3.ink : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: T3.segmentRadius)
                .fill(T3.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: T3.segmentRadius)
                        .stroke(T3.rule, lineWidth: 1)
                )
        )
    }

    // MARK: - Loading / error / events

    private var loadingView: some View {
        VStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { _ in
                HStack {
                    Rectangle()
                        .fill(T3.rule)
                        .frame(width: 60, height: 12)
                        .shimmering()
                    Spacer()
                    Rectangle()
                        .fill(T3.rule)
                        .frame(width: 120, height: 12)
                        .shimmering()
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { TRule() }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            T3IconImage(systemName: "exclamationmark.triangle")
                .frame(width: 28, height: 28)
                .foregroundStyle(T3.danger)
            Text("Couldn't load history")
                .font(T3.inter(18, weight: .medium))
                .foregroundStyle(T3.ink)
            Text(message)
                .font(T3.inter(13, weight: .regular))
                .foregroundStyle(T3.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button {
                Task { await load() }
            } label: {
                Text("Retry")
                    .font(T3.inter(13, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 72)
    }

    private var eventsList: some View {
        let grouped = groupByHour(events)
        return VStack(spacing: 0) {
            ForEach(grouped, id: \.header) { section in
                TSectionHead(title: section.header, count: "\(section.events.count)")
                ForEach(section.events) { event in
                    eventRow(event)
                        .overlay(alignment: .bottom) { TRule() }
                }
            }
        }
    }

    private func eventRow(_ event: ThermostatHistoryEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            T3IconImage(systemName: event.iconSystemName)
                .frame(width: 16, height: 16)
                .foregroundStyle(T3.ink)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(T3.inter(12, weight: .regular))
                        .foregroundStyle(T3.sub)
                }
            }

            Spacer()

            TLabel(text: event.relativeLabel)
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
    }

    // MARK: - Load

    private func load() async {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        let hours = window.hours
        guard let haProvider = registry.providers.first(where: { $0.id == .homeAssistant })
            as? HomeAssistantProvider else {
            isLoading = false
            errorMessage = "Home Assistant isn't connected."
            return
        }

        do {
            let points = try await haProvider.fetchThermostatHistory(
                entityID: entityID,
                hoursBack: hours
            )
            let diffed = computeEvents(from: points)
            events = diffed
            isLoading = false
        } catch {
            events = []
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Diffing / grouping

    /// Walk the chronological points and emit an event for each tuple
    /// of (state, temperature, hvacAction, presetMode) that differs
    /// from the previous retained point. The first point never emits
    /// — we need two points to define a change.
    private func computeEvents(
        from points: [HomeAssistantProvider.HAHistoryPoint]
    ) -> [ThermostatHistoryEvent] {
        guard points.count >= 2 else { return [] }

        var results: [ThermostatHistoryEvent] = []
        var previous = points[0]

        for i in 1..<points.count {
            let current = points[i]
            let stateChanged = current.state != previous.state
            let tempChanged = current.temperature != previous.temperature
            let actionChanged = current.hvacAction != previous.hvacAction
            let presetChanged = current.presetMode != previous.presetMode

            guard stateChanged || tempChanged || actionChanged || presetChanged else {
                continue
            }

            // Build a human-readable title for whichever field(s)
            // changed. Setpoint is the most user-visible change, so
            // prefer it in the title; annotate state / preset changes
            // as subtitles when they co-occur.
            var title: String = ""
            var subtitle: String?
            var icon: String = "circle.fill"

            if tempChanged {
                let fromF = current.temperature.map { formatTempF($0) }
                let prevF = previous.temperature.map { formatTempF($0) }
                switch (prevF, fromF) {
                case let (.some(a), .some(b)):
                    title = "Setpoint \(a)° → \(b)°"
                case (_, .some(let b)):
                    title = "Setpoint → \(b)°"
                case (.some(let a), _):
                    title = "Setpoint \(a)° → —"
                default:
                    title = "Setpoint changed"
                }
                icon = "thermometer"
            }

            if stateChanged {
                let label = "Mode \(previous.state.capitalized) → \(current.state.capitalized)"
                if title.isEmpty {
                    title = label
                    icon = iconForState(current.state)
                } else {
                    subtitle = (subtitle.map { "\($0) · " } ?? "") + label
                }
            }

            if actionChanged, let action = current.hvacAction {
                let label = "HVAC \(action.capitalized)"
                if title.isEmpty {
                    title = label
                    icon = iconForAction(action)
                } else {
                    subtitle = (subtitle.map { "\($0) · " } ?? "") + label
                }
            }

            if presetChanged {
                let from = previous.presetMode ?? "—"
                let to = current.presetMode ?? "—"
                let label = "Preset \(from.capitalized) → \(to.capitalized)"
                if title.isEmpty {
                    title = label
                    icon = "person.crop.circle"
                } else {
                    subtitle = (subtitle.map { "\($0) · " } ?? "") + label
                }
            }

            results.append(ThermostatHistoryEvent(
                timestamp: current.timestamp,
                iconSystemName: icon,
                title: title,
                subtitle: subtitle
            ))

            previous = current
        }

        // Present newest first within the list — users reading the
        // timeline care about "what changed most recently" up top.
        return results.reversed()
    }

    /// Format a temperature in Celsius to the user's preferred unit.
    private func formatTemp(_ celsius: Double) -> String {
        if useFahrenheit {
            return String(Int((celsius * 9.0 / 5.0 + 32.0).rounded()))
        } else {
            return String(Int(celsius.rounded()))
        }
    }

    // Backward-compat alias so call sites don't need touching.
    private func formatTempF(_ celsius: Double) -> String { formatTemp(celsius) }

    private func iconForState(_ state: String) -> String {
        switch state.lowercased() {
        case "heat": return "flame"
        case "cool": return "snowflake"
        case "auto", "heat_cool": return "arrow.2.squarepath"
        case "off": return "power"
        default: return "thermometer"
        }
    }

    private func iconForAction(_ action: String) -> String {
        switch action.lowercased() {
        case "heating": return "flame"
        case "cooling": return "snowflake"
        case "idle": return "pause.circle"
        case "off": return "power"
        default: return "circle"
        }
    }

    /// Bucket events by the hour boundary of their timestamp so the
    /// section heads read "TODAY 14:00", "TODAY 13:00", etc.
    private func groupByHour(
        _ events: [ThermostatHistoryEvent]
    ) -> [HistorySection] {
        guard !events.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let hourFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:00"
            return f
        }()
        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE MMM d"
            return f
        }()

        var sections: [HistorySection] = []
        var currentKey: Date?
        var currentBucket: [ThermostatHistoryEvent] = []

        for event in events {
            let hour = calendar.date(
                from: calendar.dateComponents([.year, .month, .day, .hour], from: event.timestamp)
            ) ?? event.timestamp

            if currentKey == nil {
                currentKey = hour
            }

            if let key = currentKey, key != hour {
                let header = sectionHeader(for: key, now: now,
                                           calendar: calendar,
                                           hourFormatter: hourFormatter,
                                           dayFormatter: dayFormatter)
                sections.append(HistorySection(header: header, events: currentBucket))
                currentBucket = []
                currentKey = hour
            }

            currentBucket.append(event)
        }

        if let key = currentKey, !currentBucket.isEmpty {
            let header = sectionHeader(for: key, now: now,
                                       calendar: calendar,
                                       hourFormatter: hourFormatter,
                                       dayFormatter: dayFormatter)
            sections.append(HistorySection(header: header, events: currentBucket))
        }

        return sections
    }

    private func sectionHeader(
        for hour: Date,
        now: Date,
        calendar: Calendar,
        hourFormatter: DateFormatter,
        dayFormatter: DateFormatter
    ) -> String {
        let isToday = calendar.isDateInToday(hour)
        let isYesterday = calendar.isDateInYesterday(hour)
        let hourStr = hourFormatter.string(from: hour)
        if isToday { return "Today \(hourStr)" }
        if isYesterday { return "Yesterday \(hourStr)" }
        return "\(dayFormatter.string(from: hour)) \(hourStr)"
    }
}

// MARK: - Local view models

/// One diff-level event shown in the history list. Built from one
/// or more HAHistoryPoint rows where something meaningfully changed.
private struct ThermostatHistoryEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let iconSystemName: String
    let title: String
    let subtitle: String?

    /// "5m ago", "2h ago", "Apr 17". Cheap every-frame recompute;
    /// the list is short.
    var relativeLabel: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: timestamp, relativeTo: Date())
    }
}

private struct HistorySection {
    let header: String
    let events: [ThermostatHistoryEvent]
}

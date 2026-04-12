//
//  SmokeAlarmEventStore.swift
//  house connect
//
//  Persists smoke alarm events (self-test results, battery checks,
//  connectivity changes, smoke/CO detections) so the Recent Events
//  card on SmokeAlarmDetailView shows real history instead of
//  hardcoded placeholders.
//
//  Storage: JSON in Application Support, keyed by accessory native ID.
//  Each device keeps up to 50 events; older entries are pruned on save.
//
//  Event sources:
//    - DemoNestProvider seeds sample events on first start
//    - SmokeAlertController logs detection events when alerts fire
//    - A real Nest provider would log events from the SDM event stream
//

import Foundation
import Observation

/// A single recorded event for a smoke/CO alarm.
struct SmokeAlarmEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let kind: Kind
    let date: Date
    /// Optional detail text (e.g. "Smoke level: low").
    let detail: String?

    init(id: UUID = UUID(), kind: Kind, date: Date = Date(), detail: String? = nil) {
        self.id = id
        self.kind = kind
        self.date = date
        self.detail = detail
    }

    enum Kind: String, Codable, Sendable {
        case selfTestPassed
        case selfTestFailed
        case smokeDetected
        case smokeCleared
        case coDetected
        case coCleared
        case batteryCheck
        case batteryLow
        case wifiConnected
        case wifiDisconnected
        case simulationStarted
        case simulationEnded
    }

    /// SF Symbol name for this event kind.
    var iconName: String {
        switch kind {
        case .selfTestPassed:     return "checkmark.circle.fill"
        case .selfTestFailed:     return "xmark.circle.fill"
        case .smokeDetected:      return "smoke.fill"
        case .smokeCleared:       return "checkmark.shield.fill"
        case .coDetected:         return "aqi.high"
        case .coCleared:          return "checkmark.shield.fill"
        case .batteryCheck:       return "battery.100"
        case .batteryLow:         return "battery.25"
        case .wifiConnected:      return "wifi"
        case .wifiDisconnected:   return "wifi.slash"
        case .simulationStarted:  return "play.circle.fill"
        case .simulationEnded:    return "stop.circle.fill"
        }
    }

    /// Human-readable title.
    var title: String {
        switch kind {
        case .selfTestPassed:     return "Self-test passed"
        case .selfTestFailed:     return "Self-test failed"
        case .smokeDetected:      return "Smoke detected"
        case .smokeCleared:       return "Smoke cleared"
        case .coDetected:         return "CO detected"
        case .coCleared:          return "CO cleared"
        case .batteryCheck:       return "Battery check"
        case .batteryLow:         return "Battery low"
        case .wifiConnected:      return "Connected to Wi-Fi"
        case .wifiDisconnected:   return "Wi-Fi disconnected"
        case .simulationStarted:  return "Alert simulation started"
        case .simulationEnded:    return "Alert simulation ended"
        }
    }

    /// Color for the event icon.
    var iconColor: String {
        switch kind {
        case .selfTestPassed, .smokeCleared, .coCleared, .wifiConnected, .batteryCheck:
            return "green"
        case .selfTestFailed, .smokeDetected, .coDetected, .batteryLow:
            return "red"
        case .wifiDisconnected:
            return "orange"
        case .simulationStarted, .simulationEnded:
            return "blue"
        }
    }

    /// Relative time string for display.
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Store

@MainActor
@Observable
final class SmokeAlarmEventStore {
    /// Events keyed by accessory native ID.
    private var eventsByDevice: [String: [SmokeAlarmEvent]] = [:]

    private let fileURL: URL
    private let maxEventsPerDevice = 50

    @ObservationIgnored private var didLoad = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let fm = FileManager.default
            let base = (try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true))
                ?? fm.temporaryDirectory
            let appDir = base.appendingPathComponent("house connect", isDirectory: true)
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.fileURL = appDir.appendingPathComponent("smoke-alarm-events.json")
        }
    }

    /// Returns events for a specific device, newest first.
    func events(for accessoryNativeID: String) -> [SmokeAlarmEvent] {
        loadIfNeeded()
        return (eventsByDevice[accessoryNativeID] ?? [])
            .sorted { $0.date > $1.date }
    }

    /// Records a new event for a device.
    func record(_ event: SmokeAlarmEvent, for accessoryNativeID: String) {
        loadIfNeeded()
        var list = eventsByDevice[accessoryNativeID] ?? []
        list.append(event)
        // Prune oldest if over limit
        if list.count > maxEventsPerDevice {
            list = Array(list.sorted { $0.date > $1.date }.prefix(maxEventsPerDevice))
        }
        eventsByDevice[accessoryNativeID] = list
        save()
    }

    /// Seeds events for a device if it has none. Used by DemoNestProvider
    /// to populate sample history on first launch.
    func seedIfEmpty(for accessoryNativeID: String, events: [SmokeAlarmEvent]) {
        loadIfNeeded()
        guard eventsByDevice[accessoryNativeID] == nil ||
              eventsByDevice[accessoryNativeID]?.isEmpty == true else { return }
        eventsByDevice[accessoryNativeID] = events
        save()
    }

    // MARK: - Persistence

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            eventsByDevice = try decoder.decode(
                [String: [SmokeAlarmEvent]].self, from: data
            )
        } catch {
            // Corrupt — start fresh.
            eventsByDevice = [:]
        }
    }

    private func save() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(eventsByDevice)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal.
        }
    }
}

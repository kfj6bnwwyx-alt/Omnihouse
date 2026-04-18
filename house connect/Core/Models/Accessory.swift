//
//  Accessory.swift
//  house connect
//
//  The unified cross-ecosystem device. Populated by providers, consumed by the UI.
//  The UI NEVER touches HomeKit / SmartThings / Nest types directly — only this.
//

import Foundation

/// Compound identifier that namespaces native IDs by provider.
/// Makes routing trivial: `registry.execute(cmd, on: id)` just reads `id.provider`.
struct AccessoryID: Hashable, Sendable, Codable {
    let provider: ProviderID
    let nativeID: String
}

/// Provider namespace. Add a case per ecosystem as they come online.
enum ProviderID: String, Hashable, Sendable, CaseIterable, Codable {
    case homeKit
    case smartThings
    case sonos
    case nest
    case homeAssistant

    /// User-facing brand label. Kept on the enum (not in a random view
    /// file) so every screen pulls the same string.
    var displayLabel: String {
        switch self {
        case .homeKit: "HomeKit"
        case .smartThings: "SmartThings"
        case .sonos: "Sonos"
        case .nest: "Nest"
        case .homeAssistant: "Home Assistant"
        }
    }
}

/// Unified device model.
///
/// Most fields are provider-agnostic; the two speaker-group fields at
/// the bottom (`groupedParts`, `speakerGroup`) are currently only
/// populated by `SonosProvider`. They're on the base model anyway so
/// any future ecosystem with a "this physical thing is really N pieces
/// welded together" (HomeKit accessory services groups, Matter bridged
/// devices, etc.) can reuse the same UI code.
struct Accessory: Identifiable, Hashable, Sendable, Codable {
    let id: AccessoryID
    var name: String
    var category: Category
    var roomID: String?
    var isReachable: Bool
    var capabilities: [Capability]

    /// Bonded / structural parts of a single logical device. Non-nil on
    /// Sonos home-theater setups (e.g. Arc + Sub + two rears render as
    /// one `Accessory` with `groupedParts = ["Family Room", "Sub",
    /// "Rear Left", "Rear Right"]`). The satellite players ARE
    /// filtered out of the provider's top-level `accessories` list —
    /// they only appear as entries in this array.
    ///
    /// `nil` for ordinary devices; non-nil signals "render a bonded-set
    /// chip on the tile and a Parts section in the detail view".
    var groupedParts: [String]? = nil

    /// Casual zone grouping membership — e.g. the user has "Family
    /// Room + Kitchen + Office" playing together in the Sonos app.
    /// Unlike `groupedParts`, each participating room still appears
    /// as its own top-level accessory; this field just tells the UI
    /// there's an overlay to render.
    ///
    /// `nil` means "this speaker is playing alone right now".
    var speakerGroup: SpeakerGroupMembership? = nil

    enum Category: String, Sendable, CaseIterable, Codable {
        case light
        case `switch`
        case outlet
        case thermostat
        case lock
        case sensor
        case camera
        case fan
        case blinds
        case speaker
        /// A TV / display. Added 2026-04-11 for the Samsung Frame TV
        /// detail screen (Pencil `GrzJY`). Inferred by
        /// `SmartThingsCapabilityMapper` from `tvChannel` /
        /// `mediaInputSource` / `samsungvd.mediaInputSource`, and by
        /// `HomeKitProvider` from `HMAccessoryCategoryTypeTelevision`.
        case television
        /// Smoke / CO detector (Nest Protect, etc.). Distinguished from
        /// generic `.sensor` so `DeviceDetailView` routes to
        /// `SmokeAlarmDetailView` instead of the generic sensor screen.
        case smokeAlarm
        case other
    }
}

/// Describes a room's participation in a casual multi-room audio group.
/// `isCoordinator` tells the UI which room is driving transport — only
/// the coordinator's play/pause/next actually affects the group, so the
/// detail view can surface that distinction (or bounce non-coordinator
/// transport commands to the coordinator under the hood later).
struct SpeakerGroupMembership: Hashable, Sendable, Codable {
    /// Stable identifier for the group as reported by the provider.
    /// Sonos uses e.g. `RINCON_ARC:1234`; other providers can use
    /// whatever they want since we never render this.
    let groupID: String

    /// True iff THIS accessory is the group's transport coordinator.
    let isCoordinator: Bool

    /// Display names of the OTHER rooms currently playing along.
    /// Excludes `self` so UI strings read naturally as
    /// "Playing with Kitchen, Office".
    let otherMemberNames: [String]

    /// Current group-wide master volume (0...100), populated by the
    /// provider when it has a value to report. Sonos fills this via
    /// `GroupRenderingControl::GetGroupVolume` on the coordinator and
    /// then mirrors it onto every member's snapshot so the detail
    /// view can render a working "Group Volume" slider no matter
    /// which member the user happens to be viewing. Nil means "not
    /// yet known" — either the fetch hasn't run, the speaker is
    /// standalone, or the SOAP call faulted (old firmware). The UI
    /// falls back to hiding the group-volume row in that case.
    var groupVolume: Int?

    init(
        groupID: String,
        isCoordinator: Bool,
        otherMemberNames: [String],
        groupVolume: Int? = nil
    ) {
        self.groupID = groupID
        self.isCoordinator = isCoordinator
        self.otherMemberNames = otherMemberNames
        self.groupVolume = groupVolume
    }
}

extension Accessory {
    /// Convenience lookup for the current value of a capability kind.
    func capability(of kind: Capability.Kind) -> Capability? {
        capabilities.first { $0.kind == kind }
    }

    /// Nil means "this accessory has no power capability" (e.g. a sensor).
    var isOn: Bool? {
        if case .power(let on) = capability(of: .power) { return on }
        return nil
    }

    var brightness: Double? {
        if case .brightness(let v) = capability(of: .brightness) { return v }
        return nil
    }

    var currentTemperature: Double? {
        if case .currentTemperature(let c) = capability(of: .currentTemperature) { return c }
        return nil
    }

    /// Thermostat operating mode. Nil means either "not a thermostat" OR
    /// "thermostat with no mode reporting" — the UI shows Heat/Cool/Auto/Off
    /// chips as disabled placeholders in that case.
    var hvacMode: HVACMode? {
        if case .hvacMode(let m) = capability(of: .hvacMode) { return m }
        return nil
    }

    // MARK: - Media helpers

    var playbackState: PlaybackState? {
        if case .playback(let state) = capability(of: .playback) { return state }
        return nil
    }

    var volumePercent: Int? {
        if case .volume(let v) = capability(of: .volume) { return v }
        return nil
    }

    var isMuted: Bool? {
        if case .mute(let m) = capability(of: .mute) { return m }
        return nil
    }

    var nowPlaying: NowPlaying? {
        if case .nowPlaying(let np) = capability(of: .nowPlaying) { return np }
        return nil
    }

    /// Nil = "this player doesn't report shuffle state" (e.g. radio). The
    /// UI should render the button as disabled in that case instead of
    /// hiding it, so the transport row stays visually stable.
    var isShuffling: Bool? {
        if case .shuffle(let on) = capability(of: .shuffle) { return on }
        return nil
    }

    /// Nil = "this player doesn't report repeat state".
    var repeatMode: RepeatMode? {
        if case .repeatMode(let m) = capability(of: .repeatMode) { return m }
        return nil
    }

    /// True if the accessory exposes any media transport control.
    /// Used by UI to decide whether to render the media controls section.
    var isMediaPlayer: Bool {
        capability(of: .playback) != nil || capability(of: .volume) != nil
    }

    // MARK: - Safety / environment helpers

    var isSmokeDetected: Bool? {
        if case .smokeDetected(let v) = capability(of: .smokeDetected) { return v }
        return nil
    }

    var isCODetected: Bool? {
        if case .coDetected(let v) = capability(of: .coDetected) { return v }
        return nil
    }

    var humidityPercent: Int? {
        if case .humidity(let p) = capability(of: .humidity) { return p }
        return nil
    }

    // MARK: - Source / input helpers (TV, media player)

    var currentSource: String? {
        if case .currentSource(let s) = capability(of: .currentSource) { return s }
        return nil
    }

    var sourceList: [String]? {
        if case .sourceList(let list) = capability(of: .sourceList) { return list }
        return nil
    }
}

// MARK: - User-facing labels
//
// Kept next to the model so every screen pulls the same string. Used by
// `T3AccessoryDetailView` (and any future generic fallback) to render
// capability rows and category identifiers without hard-coding strings
// in view files.

extension Accessory.Category {
    var displayLabel: String {
        switch self {
        case .light: "Light"
        case .switch: "Switch"
        case .outlet: "Outlet"
        case .thermostat: "Thermostat"
        case .lock: "Lock"
        case .sensor: "Sensor"
        case .camera: "Camera"
        case .fan: "Fan"
        case .blinds: "Blinds"
        case .speaker: "Speaker"
        case .television: "Television"
        case .smokeAlarm: "Smoke Alarm"
        case .other: "Other"
        }
    }
}

extension Capability.Kind {
    var displayLabel: String {
        switch self {
        case .power: "Power"
        case .brightness: "Brightness"
        case .hue: "Hue"
        case .saturation: "Saturation"
        case .colorTemperature: "Color Temperature"
        case .currentTemperature: "Current Temperature"
        case .targetTemperature: "Target Temperature"
        case .hvacMode: "HVAC Mode"
        case .contactSensor: "Contact Sensor"
        case .motionSensor: "Motion Sensor"
        case .batteryLevel: "Battery Level"
        case .playback: "Playback"
        case .volume: "Volume"
        case .mute: "Mute"
        case .nowPlaying: "Now Playing"
        case .shuffle: "Shuffle"
        case .repeatMode: "Repeat Mode"
        case .smokeDetected: "Smoke Detection"
        case .coDetected: "CO Detection"
        case .humidity: "Humidity"
        case .hvacAction: "HVAC Action"
        case .presetMode: "Preset Mode"
        case .presetModes: "Preset Modes"
        case .climateFanMode: "Climate Fan Mode"
        case .climateFanModes: "Climate Fan Modes"
        case .currentSource: "Source"
        case .sourceList: "Source List"
        case .mediaPosition: "Media Position"
        case .mediaDuration: "Media Duration"
        case .currentEffect: "Effect"
        case .effectList: "Effect List"
        case .fanSpeed: "Fan Speed"
        case .fanDirection: "Fan Direction"
        case .coverPosition: "Cover Position"
        }
    }
}

extension Capability {
    /// Convenience so view code can stay at the enum level without
    /// peeking at `.kind`.
    var displayLabel: String { kind.displayLabel }
}

//
//  Capability.swift
//  house connect
//
//  Unified, ecosystem-agnostic vocabulary for what an accessory can do
//  and what state it's in. Providers (HomeKit, SmartThings, Sonos, Nest, ...)
//  translate their native characteristics/attributes into these cases.
//

import Foundation

/// Transport state for media players. Mirrors the AVTransport/UPnP vocabulary
/// because that's what the first real media provider (Sonos) emits, and the
/// SmartThings / HomeKit equivalents all collapse to these four values.
enum PlaybackState: String, Hashable, Sendable, Codable {
    case playing
    case paused
    case stopped
    case transitioning
    case unknown
}

/// Now-playing metadata. All fields optional because upstream providers
/// vary — some give us artist + title, some only a stream URL.
///
/// `coverArtURL` was added in Tier 2F (2026-04-11). Sonos returns it as
/// a relative path like `/getaa?s=1&u=...` off the player's own IP; the
/// provider resolves it to an absolute http URL before setting this
/// field so the UI can feed it straight into `AsyncImage`.
struct NowPlaying: Hashable, Sendable, Codable {
    var title: String?
    var artist: String?
    var album: String?
    var coverArtURL: URL?
}

/// Repeat mode for media players. Three-state enum because every real
/// player (Sonos, SmartThings media controllers, HomeKit CarPlay bridges)
/// exposes exactly these three values. We translate to each provider's
/// native vocabulary in its capability mapper — e.g. Sonos combines
/// shuffle + repeat into a single `PlayMode` string, so the provider
/// does the cross-product internally.
enum RepeatMode: String, Hashable, Sendable, Codable, CaseIterable {
    case off
    case all
    case one
}

/// HVAC operating mode for thermostats. Mirrors the four values HomeKit's
/// `HMCharacteristicTypeTargetHeatingCoolingState` advertises, and matches
/// SmartThings' `thermostatMode` capability (which also lists exactly
/// "off", "heat", "cool", "auto" as its canonical values).
///
/// Kept as a String raw-value so we can persist it inside scenes (Scene.swift
/// Codable encoding uses the rawValue directly) without a second adapter.
enum HVACMode: String, Hashable, Sendable, Codable, CaseIterable {
    case off
    case heat
    case cool
    case auto
}

/// A single controllable or observable feature of an accessory.
/// Add a case only when at least one provider can emit or accept it.
enum Capability: Hashable, Sendable {
    case power(isOn: Bool)
    case brightness(value: Double)          // 0.0 ... 1.0
    case hue(degrees: Double)               // 0.0 ... 360.0
    case saturation(value: Double)          // 0.0 ... 1.0
    case colorTemperature(mireds: Int)      // ~140 ... 500
    case currentTemperature(celsius: Double)
    case targetTemperature(celsius: Double)
    case hvacMode(HVACMode)
    case contactSensor(isOpen: Bool)
    case motionSensor(isDetected: Bool)
    case batteryLevel(percent: Int)

    // MARK: - Media (Phase 3a+)
    case playback(state: PlaybackState)
    case volume(percent: Int)               // 0 ... 100
    case mute(isMuted: Bool)
    case nowPlaying(NowPlaying)
    case shuffle(isOn: Bool)
    case repeatMode(RepeatMode)

    // MARK: - Safety sensors (Phase 6 — Nest Protect)
    // NOTE: Google removed Nest Protect from the SDM API, so these
    // capabilities are only populated by DemoNestProvider today.
    // Kept in the model for future-proofing and to drive the
    // SmokeAlarmDetailView UI data-driven instead of hardcoded.
    case smokeDetected(Bool)
    case coDetected(Bool)

    // MARK: - Environment
    case humidity(percent: Int)               // 0 ... 100
}

extension Capability {
    /// Coarse kind used for lookup, UI grouping, and icon selection.
    /// Strips the associated value so two readings of the same kind match.
    enum Kind: String, Hashable, Sendable, CaseIterable {
        case power
        case brightness
        case hue
        case saturation
        case colorTemperature
        case currentTemperature
        case targetTemperature
        case hvacMode
        case contactSensor
        case motionSensor
        case batteryLevel
        case playback
        case volume
        case mute
        case nowPlaying
        case shuffle
        case repeatMode
        case smokeDetected
        case coDetected
        case humidity
    }

    var kind: Kind {
        switch self {
        case .power: .power
        case .brightness: .brightness
        case .hue: .hue
        case .saturation: .saturation
        case .colorTemperature: .colorTemperature
        case .currentTemperature: .currentTemperature
        case .targetTemperature: .targetTemperature
        case .hvacMode: .hvacMode
        case .contactSensor: .contactSensor
        case .motionSensor: .motionSensor
        case .batteryLevel: .batteryLevel
        case .playback: .playback
        case .volume: .volume
        case .mute: .mute
        case .nowPlaying: .nowPlaying
        case .shuffle: .shuffle
        case .repeatMode: .repeatMode
        case .smokeDetected: .smokeDetected
        case .coDetected: .coDetected
        case .humidity: .humidity
        }
    }
}

/// Commands the UI issues back to a provider. Input side of `Capability`.
/// Not every capability is writable (sensors aren't), so this is a separate type.
enum AccessoryCommand: Hashable, Sendable {
    // Lighting / power / climate
    case setPower(Bool)
    case setBrightness(Double)
    case setHue(Double)
    case setSaturation(Double)
    case setColorTemperature(Int)
    case setTargetTemperature(Double)
    case setHVACMode(HVACMode)

    // Media transport
    case play
    case pause
    case stop
    case next
    case previous
    case setVolume(Int)                     // 0 ... 100, per-speaker
    /// Group-wide master volume (0...100). Providers that support
    /// multi-room audio (Sonos) route this to the group coordinator
    /// and scale every member's individual volume proportionally.
    /// Providers with no native group-volume concept can implement
    /// it as an iteration over members or throw unsupportedCommand.
    case setGroupVolume(Int)
    case setMute(Bool)
    case setShuffle(Bool)
    case setRepeatMode(RepeatMode)

    // MARK: - Speaker grouping (Phase 3b)
    //
    // Cross-provider in shape, Sonos-only in practice today. The target
    // parameter on `joinSpeakerGroup` names ANOTHER accessory whose
    // currently-playing zone group we want to join — the provider is
    // responsible for resolving that to the right low-level primitive
    // (on Sonos: set AVTransportURI to `x-rincon:<coordinatorUUID>`).
    // Non-Sonos providers throw `.unsupportedCommand`.
    case joinSpeakerGroup(target: AccessoryID)
    case leaveSpeakerGroup

    // MARK: - Safety (Phase 6 — Nest Protect)
    /// Trigger the device's built-in self-test. Currently only meaningful
    /// for smoke/CO alarms. Providers that don't support it throw
    /// `.unsupportedCommand`.
    case selfTest
}

// MARK: - Capability Codable

/// Custom Codable for the associated-value enum. Uses a `kind` discriminator
/// string plus per-case payload keys. Decode failures on individual
/// capabilities are tolerable — the cache just drops unknown future cases.
extension Capability: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        // Payload keys — reused across cases where the type matches.
        case boolValue, doubleValue, intValue, stringValue
        case title, artist, album, coverArtURL
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind.rawValue, forKey: .kind)
        switch self {
        case .power(let v):              try c.encode(v, forKey: .boolValue)
        case .brightness(let v):         try c.encode(v, forKey: .doubleValue)
        case .hue(let v):                try c.encode(v, forKey: .doubleValue)
        case .saturation(let v):         try c.encode(v, forKey: .doubleValue)
        case .colorTemperature(let v):   try c.encode(v, forKey: .intValue)
        case .currentTemperature(let v): try c.encode(v, forKey: .doubleValue)
        case .targetTemperature(let v):  try c.encode(v, forKey: .doubleValue)
        case .hvacMode(let v):           try c.encode(v.rawValue, forKey: .stringValue)
        case .contactSensor(let v):      try c.encode(v, forKey: .boolValue)
        case .motionSensor(let v):       try c.encode(v, forKey: .boolValue)
        case .batteryLevel(let v):       try c.encode(v, forKey: .intValue)
        case .playback(let v):           try c.encode(v.rawValue, forKey: .stringValue)
        case .volume(let v):             try c.encode(v, forKey: .intValue)
        case .mute(let v):               try c.encode(v, forKey: .boolValue)
        case .nowPlaying(let np):
            try c.encodeIfPresent(np.title, forKey: .title)
            try c.encodeIfPresent(np.artist, forKey: .artist)
            try c.encodeIfPresent(np.album, forKey: .album)
            try c.encodeIfPresent(np.coverArtURL, forKey: .coverArtURL)
        case .shuffle(let v):            try c.encode(v, forKey: .boolValue)
        case .repeatMode(let v):         try c.encode(v.rawValue, forKey: .stringValue)
        case .smokeDetected(let v):      try c.encode(v, forKey: .boolValue)
        case .coDetected(let v):         try c.encode(v, forKey: .boolValue)
        case .humidity(let v):           try c.encode(v, forKey: .intValue)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kindRaw = try c.decode(String.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindRaw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown capability kind: \(kindRaw)"
            )
        }
        switch kind {
        case .power:              self = .power(isOn: try c.decode(Bool.self, forKey: .boolValue))
        case .brightness:         self = .brightness(value: try c.decode(Double.self, forKey: .doubleValue))
        case .hue:                self = .hue(degrees: try c.decode(Double.self, forKey: .doubleValue))
        case .saturation:         self = .saturation(value: try c.decode(Double.self, forKey: .doubleValue))
        case .colorTemperature:   self = .colorTemperature(mireds: try c.decode(Int.self, forKey: .intValue))
        case .currentTemperature: self = .currentTemperature(celsius: try c.decode(Double.self, forKey: .doubleValue))
        case .targetTemperature:  self = .targetTemperature(celsius: try c.decode(Double.self, forKey: .doubleValue))
        case .hvacMode:
            let raw = try c.decode(String.self, forKey: .stringValue)
            self = .hvacMode(HVACMode(rawValue: raw) ?? .off)
        case .contactSensor:      self = .contactSensor(isOpen: try c.decode(Bool.self, forKey: .boolValue))
        case .motionSensor:       self = .motionSensor(isDetected: try c.decode(Bool.self, forKey: .boolValue))
        case .batteryLevel:       self = .batteryLevel(percent: try c.decode(Int.self, forKey: .intValue))
        case .playback:
            let raw = try c.decode(String.self, forKey: .stringValue)
            self = .playback(state: PlaybackState(rawValue: raw) ?? .unknown)
        case .volume:             self = .volume(percent: try c.decode(Int.self, forKey: .intValue))
        case .mute:               self = .mute(isMuted: try c.decode(Bool.self, forKey: .boolValue))
        case .nowPlaying:
            self = .nowPlaying(NowPlaying(
                title: try c.decodeIfPresent(String.self, forKey: .title),
                artist: try c.decodeIfPresent(String.self, forKey: .artist),
                album: try c.decodeIfPresent(String.self, forKey: .album),
                coverArtURL: try c.decodeIfPresent(URL.self, forKey: .coverArtURL)
            ))
        case .shuffle:            self = .shuffle(isOn: try c.decode(Bool.self, forKey: .boolValue))
        case .repeatMode:
            let raw = try c.decode(String.self, forKey: .stringValue)
            self = .repeatMode(RepeatMode(rawValue: raw) ?? .off)
        case .smokeDetected:      self = .smokeDetected(try c.decode(Bool.self, forKey: .boolValue))
        case .coDetected:         self = .coDetected(try c.decode(Bool.self, forKey: .boolValue))
        case .humidity:           self = .humidity(percent: try c.decode(Int.self, forKey: .intValue))
        }
    }
}

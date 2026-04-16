//
//  Scene.swift
//  house connect
//
//  Cross-ecosystem scene model. A scene is an ordered list of
//  (accessoryID, command) pairs — running it fires them all in parallel
//  via the ProviderRegistry. Scenes are local-only for now; when the
//  Hetzner backend lands in Phase 4+ we'll sync these up and let the
//  automations engine reuse the same vocabulary.
//
//  Why a dedicated `Scene` type instead of reusing HomeKit's `HMActionSet`:
//  HomeKit's scene model can only target HomeKit accessories. Our headline
//  feature is "turn off every light AND pause Sonos AND set the Nest to
//  68°" from a single tap — that crosses provider boundaries, so scenes
//  have to live above the provider layer.
//
//  ⚠ NAMING COLLISION: SwiftUI ships a `Scene` protocol for app scenes.
//  Inside this app the term "scene" unambiguously means "lighting/media
//  preset", so we keep the short name but put it in `Core/Scenes/` to
//  reduce ambiguity at the call site. Views that need SwiftUI's `Scene`
//  reach for `SwiftUI.Scene` — there's one such usage in house_connectApp.
//

import Foundation

/// One step in a scene: "run `command` on `accessory`".
/// Stored in a dedicated struct instead of a tuple so it's Codable, so it
/// can carry metadata later (e.g. per-action delay, skip-on-error flag).
struct SceneAction: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var accessoryID: AccessoryID
    var command: AccessoryCommand

    init(id: UUID = UUID(), accessoryID: AccessoryID, command: AccessoryCommand) {
        self.id = id
        self.accessoryID = accessoryID
        self.command = command
    }
}

/// A user-defined cross-ecosystem preset.
struct HCScene: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    /// SF Symbol name, chosen by the user from a short curated list.
    var iconSystemName: String
    var actions: [SceneAction]

    init(id: UUID = UUID(),
         name: String,
         iconSystemName: String,
         actions: [SceneAction] = []) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.actions = actions
    }
}

// MARK: - Codable shims
//
// AccessoryID and Capability are now Codable directly on their types
// (see Accessory.swift and Capability.swift). AccessoryCommand keeps its
// hand-rolled Codable here because it's only needed for scene persistence.

extension AccessoryCommand: Codable {
    // Tagged-union encoding. `kind` names the case, `value` carries the
    // associated payload (or is absent for no-arg cases). Keeps the JSON
    // readable for debugging without locking us into a specific library.
    enum CodingKeys: String, CodingKey { case kind, value, value2 }

    private enum Kind: String, Codable {
        case setPower, setBrightness, setHue, setSaturation
        case setColorTemperature, setTargetTemperature, setHVACMode
        case play, pause, stop, next, previous
        case setVolume, setGroupVolume, setMute
        case setShuffle, setRepeatMode
        case joinSpeakerGroup, leaveSpeakerGroup
        case selfTest
        case selectSource, setPresetMode, setClimateFanMode
        case setFanSpeed, setFanDirection, setCoverPosition
        case playMedia, seekTo, setEffect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .setPower:
            self = .setPower(try c.decode(Bool.self, forKey: .value))
        case .setBrightness:
            self = .setBrightness(try c.decode(Double.self, forKey: .value))
        case .setHue:
            self = .setHue(try c.decode(Double.self, forKey: .value))
        case .setSaturation:
            self = .setSaturation(try c.decode(Double.self, forKey: .value))
        case .setColorTemperature:
            self = .setColorTemperature(try c.decode(Int.self, forKey: .value))
        case .setTargetTemperature:
            self = .setTargetTemperature(try c.decode(Double.self, forKey: .value))
        case .setHVACMode:
            self = .setHVACMode(try c.decode(HVACMode.self, forKey: .value))
        case .play: self = .play
        case .pause: self = .pause
        case .stop: self = .stop
        case .next: self = .next
        case .previous: self = .previous
        case .setVolume:
            self = .setVolume(try c.decode(Int.self, forKey: .value))
        case .setGroupVolume:
            self = .setGroupVolume(try c.decode(Int.self, forKey: .value))
        case .setMute:
            self = .setMute(try c.decode(Bool.self, forKey: .value))
        case .setShuffle:
            self = .setShuffle(try c.decode(Bool.self, forKey: .value))
        case .setRepeatMode:
            self = .setRepeatMode(try c.decode(RepeatMode.self, forKey: .value))
        case .joinSpeakerGroup:
            self = .joinSpeakerGroup(target: try c.decode(AccessoryID.self, forKey: .value))
        case .leaveSpeakerGroup:
            self = .leaveSpeakerGroup
        case .selfTest:
            self = .selfTest
        case .selectSource:
            self = .selectSource(try c.decode(String.self, forKey: .value))
        case .setPresetMode:
            self = .setPresetMode(try c.decode(String.self, forKey: .value))
        case .setClimateFanMode:
            self = .setClimateFanMode(try c.decode(String.self, forKey: .value))
        case .setFanSpeed:
            self = .setFanSpeed(try c.decode(Int.self, forKey: .value))
        case .setFanDirection:
            self = .setFanDirection(try c.decode(String.self, forKey: .value))
        case .setCoverPosition:
            self = .setCoverPosition(try c.decode(Int.self, forKey: .value))
        case .playMedia:
            self = .playMedia(
                contentID: try c.decode(String.self, forKey: .value),
                contentType: try c.decode(String.self, forKey: .value2)
            )
        case .seekTo:
            self = .seekTo(seconds: try c.decode(Double.self, forKey: .value))
        case .setEffect:
            self = .setEffect(try c.decode(String.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .setPower(let b):
            try c.encode(Kind.setPower, forKey: .kind)
            try c.encode(b, forKey: .value)
        case .setBrightness(let d):
            try c.encode(Kind.setBrightness, forKey: .kind)
            try c.encode(d, forKey: .value)
        case .setHue(let d):
            try c.encode(Kind.setHue, forKey: .kind)
            try c.encode(d, forKey: .value)
        case .setSaturation(let d):
            try c.encode(Kind.setSaturation, forKey: .kind)
            try c.encode(d, forKey: .value)
        case .setColorTemperature(let i):
            try c.encode(Kind.setColorTemperature, forKey: .kind)
            try c.encode(i, forKey: .value)
        case .setTargetTemperature(let d):
            try c.encode(Kind.setTargetTemperature, forKey: .kind)
            try c.encode(d, forKey: .value)
        case .setHVACMode(let m):
            try c.encode(Kind.setHVACMode, forKey: .kind)
            try c.encode(m, forKey: .value)
        case .play: try c.encode(Kind.play, forKey: .kind)
        case .pause: try c.encode(Kind.pause, forKey: .kind)
        case .stop: try c.encode(Kind.stop, forKey: .kind)
        case .next: try c.encode(Kind.next, forKey: .kind)
        case .previous: try c.encode(Kind.previous, forKey: .kind)
        case .setVolume(let i):
            try c.encode(Kind.setVolume, forKey: .kind)
            try c.encode(i, forKey: .value)
        case .setGroupVolume(let i):
            try c.encode(Kind.setGroupVolume, forKey: .kind)
            try c.encode(i, forKey: .value)
        case .setMute(let b):
            try c.encode(Kind.setMute, forKey: .kind)
            try c.encode(b, forKey: .value)
        case .setShuffle(let b):
            try c.encode(Kind.setShuffle, forKey: .kind)
            try c.encode(b, forKey: .value)
        case .setRepeatMode(let m):
            try c.encode(Kind.setRepeatMode, forKey: .kind)
            try c.encode(m, forKey: .value)
        case .joinSpeakerGroup(let target):
            try c.encode(Kind.joinSpeakerGroup, forKey: .kind)
            try c.encode(target, forKey: .value)
        case .leaveSpeakerGroup:
            try c.encode(Kind.leaveSpeakerGroup, forKey: .kind)
        case .selfTest:
            try c.encode(Kind.selfTest, forKey: .kind)
        case .selectSource(let s):
            try c.encode(Kind.selectSource, forKey: .kind)
            try c.encode(s, forKey: .value)
        case .setPresetMode(let s):
            try c.encode(Kind.setPresetMode, forKey: .kind)
            try c.encode(s, forKey: .value)
        case .setClimateFanMode(let s):
            try c.encode(Kind.setClimateFanMode, forKey: .kind)
            try c.encode(s, forKey: .value)
        case .setFanSpeed(let i):
            try c.encode(Kind.setFanSpeed, forKey: .kind)
            try c.encode(i, forKey: .value)
        case .setFanDirection(let s):
            try c.encode(Kind.setFanDirection, forKey: .kind)
            try c.encode(s, forKey: .value)
        case .setCoverPosition(let i):
            try c.encode(Kind.setCoverPosition, forKey: .kind)
            try c.encode(i, forKey: .value)
        case .playMedia(let contentID, let contentType):
            try c.encode(Kind.playMedia, forKey: .kind)
            try c.encode(contentID, forKey: .value)
            try c.encode(contentType, forKey: .value2)
        case .seekTo(let seconds):
            try c.encode(Kind.seekTo, forKey: .kind)
            try c.encode(seconds, forKey: .value)
        case .setEffect(let s):
            try c.encode(Kind.setEffect, forKey: .kind)
            try c.encode(s, forKey: .value)
        }
    }
}

//
//  SceneEditorView.swift
//  house connect
//
//  Edits a single scene: name, icon, and the list of per-device actions
//  that fire when the scene runs. Also handles create-new (sceneID == nil).
//
//  Design notes:
//  -------------
//  - Icon picker is a flat row of curated SF Symbols rather than a
//    full icon browser. Ten icons cover every scene concept we've
//    drawn so far (Morning/Away/Movie/Sleep/Focus/Party/…) and a long
//    list would overwhelm a primarily-mobile form.
//  - Per-action editing uses an inline sheet picker — user picks an
//    accessory, then picks a command appropriate for its capabilities.
//  - We don't expose every AccessoryCommand for every device. The
//    `supportedCommands(for:)` helper gates the list by capability,
//    so you can't "setBrightness" on a speaker.
//

import SwiftUI

struct SceneEditorView: View {
    @Environment(SceneStore.self) private var sceneStore
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    /// `nil` means we're creating a new scene.
    let sceneID: UUID?

    @State private var name: String = ""
    @State private var iconSystemName: String = "sparkles"
    @State private var actions: [SceneAction] = []

    @State private var showingActionPicker = false

    /// Curated list — ten icons that cover the scene concepts we've
    /// drawn in the Pencil design plus a few extras.
    private static let iconChoices = [
        "sun.max.fill", "moon.fill", "tv.fill", "shield.fill",
        "house.fill", "fork.knife", "book.fill", "music.note",
        "sparkles", "bolt.fill"
    ]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Morning, Away, Movie…", text: $name)
                    .accessibilityLabel("Scene name")
                    .accessibilityHint("Enter a name for this scene, such as Morning, Away, or Movie")
            }

            Section("Icon") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Self.iconChoices, id: \.self) { icon in
                            Button {
                                iconSystemName = icon
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Theme.radius.chip)
                                        .fill(icon == iconSystemName
                                              ? Theme.color.primary
                                              : Theme.color.iconChipFill)
                                        .frame(width: 48, height: 48)
                                    Image(systemName: icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(icon == iconSystemName
                                                         ? .white
                                                         : Theme.color.iconChipGlyph)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(iconAccessibilityName(icon))
                            .accessibilityAddTraits(icon == iconSystemName ? [.isSelected] : [])
                            .accessibilityHint("Set scene icon to \(iconAccessibilityName(icon))")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel("Scene icon picker, current selection: \(iconAccessibilityName(iconSystemName))")
            }

            Section {
                if actions.isEmpty {
                    Text("No actions yet. Tap Add action to wire this scene to a device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("No actions added yet. Tap Add action to wire this scene to a device.")
                } else {
                    ForEach(actions) { action in
                        ActionRow(
                            action: action,
                            accessory: registry.allAccessories
                                .first(where: { $0.id == action.accessoryID })
                        )
                    }
                    .onDelete { actions.remove(atOffsets: $0) }
                }
                Button {
                    showingActionPicker = true
                } label: {
                    Label("Add action", systemImage: "plus")
                }
                .accessibilityLabel("Add action")
                .accessibilityHint("Opens a picker to select a device and command for this scene")
            } header: {
                Text("Actions")
            } footer: {
                Text("All actions in a scene fire in parallel when the scene tile is tapped.")
            }
        }
        .navigationTitle(sceneID == nil ? "New Scene" : "Edit Scene")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save scene")
                    .accessibilityHint("Save this scene and return to the scenes list")
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showingActionPicker) {
            SceneActionPickerView { newAction in
                actions.append(newAction)
            }
            .environment(registry)
        }
    }

    private func iconAccessibilityName(_ icon: String) -> String {
        switch icon {
        case "sun.max.fill": return "Sun"
        case "moon.fill": return "Moon"
        case "tv.fill": return "TV"
        case "shield.fill": return "Shield"
        case "house.fill": return "House"
        case "fork.knife": return "Dining"
        case "book.fill": return "Book"
        case "music.note": return "Music"
        case "sparkles": return "Sparkles"
        case "bolt.fill": return "Bolt"
        default: return icon
        }
    }

    // MARK: - Load / Save

    private func load() {
        guard let sceneID, let existing = sceneStore.scene(id: sceneID) else {
            // Create mode — leave defaults. If the user came through
            // "+ New", pre-seed name empty and let them type.
            return
        }
        name = existing.name
        iconSystemName = existing.iconSystemName
        actions = existing.actions
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let sceneID, var existing = sceneStore.scene(id: sceneID) {
            existing.name = trimmed
            existing.iconSystemName = iconSystemName
            existing.actions = actions
            sceneStore.update(existing)
        } else {
            let new = HCScene(
                name: trimmed,
                iconSystemName: iconSystemName,
                actions: actions
            )
            sceneStore.add(new)
        }
        dismiss()
    }
}

// MARK: - Row

private struct ActionRow: View {
    let action: SceneAction
    let accessory: Accessory?

    var body: some View {
        HStack(spacing: 12) {
            IconChip(
                systemName: accessory.map { iconName(for: $0.category) } ?? "questionmark",
                size: 32
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(accessory?.name ?? "Missing device")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text(commandLabel(action.command))
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessory?.name ?? "Missing device"), \(commandLabel(action.command))")
    }

    private func iconName(for cat: Accessory.Category) -> String {
        switch cat {
        case .light: "lightbulb.fill"
        case .switch: "switch.2"
        case .outlet: "poweroutlet.type.b.fill"
        case .thermostat: "thermometer"
        case .lock: "lock.fill"
        case .sensor: "sensor.fill"
        case .camera: "video.fill"
        case .fan: "fan.fill"
        case .blinds: "blinds.horizontal.closed"
        case .speaker: "hifispeaker.fill"
        case .television: "tv.fill"
        case .smokeAlarm: "smoke.fill"
        case .other: "questionmark.app.fill"
        }
    }
}

/// Turns an AccessoryCommand into a short user-facing label. Kept in one
/// place so scene rows, history, and audit logs all use the same vocabulary.
func commandLabel(_ command: AccessoryCommand) -> String {
    switch command {
    case .setPower(let on): return on ? "Turn on" : "Turn off"
    case .setBrightness(let d): return "Set brightness to \(Int(d * 100))%"
    case .setHue(let d): return "Set hue to \(Int(d))°"
    case .setSaturation(let d): return "Set saturation to \(Int(d * 100))%"
    case .setColorTemperature(let mireds): return "Color temperature \(mireds) mireds"
    case .setTargetTemperature(let c): return "Target \(Int(c))°C"
    case .setHVACMode(let m):
        switch m {
        case .off: return "Turn off HVAC"
        case .heat: return "Heat mode"
        case .cool: return "Cool mode"
        case .auto: return "Auto mode"
        }
    case .play: return "Play"
    case .pause: return "Pause"
    case .stop: return "Stop"
    case .next: return "Next track"
    case .previous: return "Previous track"
    case .setVolume(let v): return "Set volume to \(v)%"
    case .setGroupVolume(let v): return "Set group volume to \(v)%"
    case .setMute(let m): return m ? "Mute" : "Unmute"
    case .setShuffle(let on): return on ? "Shuffle on" : "Shuffle off"
    case .setRepeatMode(let m):
        switch m {
        case .off: return "Repeat off"
        case .all: return "Repeat all"
        case .one: return "Repeat one"
        }
    case .joinSpeakerGroup:
        // Scenes don't yet let the user PICK a grouping target from
        // the action editor — it'd need a second accessory selector
        // inside the scene staging flow, which is a Phase 3b follow-up.
        // For the label path (used by history / audit / previews)
        // keep it generic so persisted scenes that were authored by
        // some other code path still render something meaningful.
        return "Join speaker group"
    case .leaveSpeakerGroup:
        return "Leave speaker group"
    case .selfTest:
        return "Run self-test"
    case .selectSource(let s):
        return "Select source: \(s)"
    case .setPresetMode(let p):
        return "Set preset: \(p)"
    case .setClimateFanMode(let m):
        return "Set fan mode: \(m)"
    case .setFanSpeed(let pct):
        return "Set fan speed to \(pct)%"
    case .setFanDirection(let d):
        return "Set fan direction: \(d)"
    case .setCoverPosition(let pct):
        return "Set cover to \(pct)%"
    case .playMedia(let id, _):
        return "Play: \(id)"
    case .seekTo(let sec):
        return "Seek to \(Int(sec))s"
    case .setEffect(let e):
        return "Set effect: \(e)"
    }
}

// MARK: - Action picker

/// Two-step picker: select an accessory, then select a command. We walk
/// the accessory's capabilities and build a list of commands that would
/// actually be honored, so the user can't stage an impossible action.
private struct SceneActionPickerView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    let onPick: (SceneAction) -> Void

    @State private var selectedAccessory: Accessory?

    var body: some View {
        NavigationStack {
            Group {
                if let accessory = selectedAccessory {
                    commandList(for: accessory)
                } else {
                    accessoryList
                }
            }
            .navigationTitle(selectedAccessory?.name ?? "Pick device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var accessoryList: some View {
        List(registry.allAccessories) { accessory in
            Button {
                selectedAccessory = accessory
            } label: {
                HStack {
                    Text(accessory.name)
                        .foregroundStyle(Theme.color.title)
                    Spacer()
                    Text(accessory.id.provider.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func commandList(for accessory: Accessory) -> some View {
        let commands = supportedCommands(for: accessory)
        if commands.isEmpty {
            ContentUnavailableView(
                "No supported commands",
                systemImage: "questionmark.circle",
                description: Text("This device doesn't expose any scene-compatible commands yet.")
            )
        } else {
            List(commands, id: \.self) { cmd in
                Button {
                    onPick(SceneAction(accessoryID: accessory.id, command: cmd))
                    dismiss()
                } label: {
                    Text(commandLabel(cmd))
                        .foregroundStyle(Theme.color.title)
                }
            }
        }
    }

    /// Walks the accessory's capabilities and builds a list of plausible
    /// commands for it. This is a scene-editor-only concern — the
    /// provider still gets to reject anything it can't handle at runtime.
    private func supportedCommands(for accessory: Accessory) -> [AccessoryCommand] {
        var out: [AccessoryCommand] = []
        if accessory.capability(of: .power) != nil {
            out.append(.setPower(true))
            out.append(.setPower(false))
        }
        if accessory.capability(of: .brightness) != nil {
            out.append(.setBrightness(0.25))
            out.append(.setBrightness(0.5))
            out.append(.setBrightness(1.0))
        }
        if accessory.capability(of: .targetTemperature) != nil {
            out.append(.setTargetTemperature(20))
            out.append(.setTargetTemperature(22))
        }
        if accessory.capability(of: .hvacMode) != nil {
            out.append(.setHVACMode(.heat))
            out.append(.setHVACMode(.cool))
            out.append(.setHVACMode(.auto))
            out.append(.setHVACMode(.off))
        }
        if accessory.capability(of: .playback) != nil {
            out.append(.play)
            out.append(.pause)
            out.append(.stop)
            out.append(.next)
            out.append(.previous)
        }
        if accessory.capability(of: .volume) != nil {
            out.append(.setVolume(20))
            out.append(.setVolume(50))
        }
        if accessory.capability(of: .mute) != nil {
            out.append(.setMute(true))
            out.append(.setMute(false))
        }
        if accessory.capability(of: .shuffle) != nil {
            out.append(.setShuffle(true))
            out.append(.setShuffle(false))
        }
        if accessory.capability(of: .repeatMode) != nil {
            out.append(.setRepeatMode(.off))
            out.append(.setRepeatMode(.all))
            out.append(.setRepeatMode(.one))
        }
        return out
    }
}

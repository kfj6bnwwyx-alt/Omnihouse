//
//  T3SceneEditorView.swift
//  house connect
//
//  T3/Swiss scene builder. Replaces the simpler `T3CreateSceneSheet`
//  (name + icon only) with a "When / Then" composition surface:
//
//    NAME     — the scene's user-facing label
//    ICON     — horizontal glyph picker (12 curated T3 icons)
//    DEVICES  — every accessory in the registry, each with a toggle.
//               Toggling a device ON captures its current state as
//               a SceneAction on the draft scene.
//
//  Save commits through `SceneStore.add(_:)` (or `update(_:)` when
//  editing an existing scene) and dismisses. Cancel backs out via
//  the nav chevron without mutating the store.
//
//  Data-capture strategy
//  ---------------------
//  When the user enables a device, we snapshot its most useful single
//  capability into a `SceneAction`:
//    • Lights → `.setBrightness(current)` if on, else `.setPower(false)`
//    • Thermostats → `.setTargetTemperature` if we have a setpoint
//    • Speakers → `.play` / `.pause` based on current playbackState
//    • TVs → `.setPower(current)`
//    • Everything else → `.setPower(current.isOn ?? false)`
//  This is intentionally narrow for v1 — richer per-capability editing
//  (color, mode, source) is deferred to a follow-up wave.
//

import SwiftUI

struct T3SceneEditorView: View {
    @Environment(SceneStore.self) private var sceneStore
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    /// Existing scene to edit, or nil for a brand-new scene.
    let editingScene: HCScene?

    @State private var sceneName: String = ""
    @State private var selectedIcon: String = "sparkles"
    @State private var enabledDeviceIDs: Set<AccessoryID> = []
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    init(editing: HCScene? = nil) {
        self.editingScene = editing
    }

    /// Curated T3 icon pool. Each entry: (SF Symbol name, mono label).
    /// `T3IconImage` will substitute a Lucide glyph where one is mapped.
    private static let iconChoices: [(sf: String, label: String)] = [
        ("sparkles", "SCENE"),
        ("sun.max.fill", "MORNING"),
        ("moon.fill", "SLEEP"),
        ("tv.fill", "MOVIE"),
        ("shield.fill", "AWAY"),
        ("house.fill", "HOME"),
        ("fork.knife", "DINNER"),
        ("book.fill", "READING"),
        ("flame.fill", "COZY"),
        ("drop.fill", "BATH"),
        ("figure.walk", "LEAVE"),
        ("bed.double.fill", "REST"),
    ]

    private var canSave: Bool {
        !sceneName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sortedAccessories: [Accessory] {
        registry.allAccessories.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                T3.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TTitle(
                            title: editingScene == nil ? "New Scene." : sceneName.isEmpty ? "Scene." : "\(sceneName).",
                            subtitle: "When · Then"
                        )

                        // Name
                        TSectionHead(title: "Name")
                        VStack(alignment: .leading, spacing: 10) {
                            TLabel(text: "SCENE NAME")
                            TextField("Movie Night", text: $sceneName)
                                .autocorrectionDisabled()
                                .focused($nameFocused)
                                .font(T3.inter(22, weight: .medium))
                                .foregroundStyle(T3.ink)
                                .submitLabel(.done)
                                .onSubmit { nameFocused = false }
                            Rectangle()
                                .fill(nameFocused ? T3.accent : T3.rule)
                                .frame(height: nameFocused ? 1.5 : 1)
                                .animation(.easeOut(duration: 0.18), value: nameFocused)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) { TRule() }
                        .overlay(alignment: .bottom) { TRule() }

                        // Icon
                        TSectionHead(
                            title: "Icon",
                            count: String(format: "%02d", Self.iconChoices.count)
                        )
                        iconPicker
                            .padding(.vertical, 14)
                            .overlay(alignment: .top) { TRule() }
                            .overlay(alignment: .bottom) { TRule() }

                        // Devices
                        TSectionHead(
                            title: "Devices",
                            count: String(format: "%02d", enabledDeviceIDs.count)
                        )
                        deviceList

                        if let errorMessage {
                            Text(errorMessage)
                                .font(T3.mono(11))
                                .tracking(0.8)
                                .foregroundStyle(T3.danger)
                                .padding(.horizontal, T3.screenPadding)
                                .padding(.top, 14)
                        }

                        // Save button
                        Button {
                            commitScene()
                        } label: {
                            Text(editingScene == nil ? "Save Scene" : "Update Scene")
                                .font(T3.inter(16, weight: .semibold))
                                .foregroundStyle(T3.page)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(canSave ? T3.ink : T3.ink.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.top, 24)

                        Spacer(minLength: 120)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(T3.ink)
                }
            }
            .onAppear {
                if let existing = editingScene {
                    sceneName = existing.name
                    selectedIcon = existing.iconSystemName
                    enabledDeviceIDs = Set(existing.actions.map(\.accessoryID))
                } else {
                    nameFocused = true
                }
            }
        }
        .presentationBackground(T3.page)
    }

    // MARK: - Icon picker

    private var iconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.iconChoices, id: \.sf) { choice in
                    Button {
                        selectedIcon = choice.sf
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Rectangle()
                                    .fill(selectedIcon == choice.sf ? T3.ink : T3.panel)
                                    .frame(width: 48, height: 48)
                                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                                T3IconImage(systemName: choice.sf)
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(selectedIcon == choice.sf ? T3.page : T3.ink)

                                // Accent ring when selected
                                if selectedIcon == choice.sf {
                                    Rectangle()
                                        .stroke(T3.accent, lineWidth: 2)
                                        .frame(width: 52, height: 52)
                                }
                            }
                            Text(choice.label)
                                .font(T3.mono(9))
                                .tracking(1.4)
                                .foregroundStyle(selectedIcon == choice.sf ? T3.ink : T3.sub)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.label)
                    .accessibilityAddTraits(selectedIcon == choice.sf ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.horizontal, T3.screenPadding)
        }
    }

    // MARK: - Device list

    private var deviceList: some View {
        VStack(spacing: 0) {
            if sortedAccessories.isEmpty {
                Text("No devices discovered yet.")
                    .font(T3.inter(14, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 22)
                    .overlay(alignment: .top) { TRule() }
            } else {
                ForEach(sortedAccessories) { accessory in
                    deviceRow(accessory)
                }
                TRule()
            }
        }
    }

    private func deviceRow(_ accessory: Accessory) -> some View {
        let isEnabled = enabledDeviceIDs.contains(accessory.id)
        let roomName = accessory.roomID.flatMap { roomID in
            registry.allRooms
                .first { $0.id == roomID && $0.provider == accessory.id.provider }?
                .name
        } ?? accessory.id.provider.displayLabel

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                T3IconImage(systemName: icon(for: accessory.category))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(T3.ink)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(accessory.name)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    TLabel(text: roomName.uppercased())
                }

                Spacer()

                TToggle(
                    isOn: Binding(
                        get: { isEnabled },
                        set: { on in
                            if on { enabledDeviceIDs.insert(accessory.id) }
                            else { enabledDeviceIDs.remove(accessory.id) }
                        }
                    ),
                    accessibilityLabel: "Include \(accessory.name)"
                )
            }

            if isEnabled, let capture = captureLabel(for: accessory) {
                HStack {
                    Spacer().frame(width: 40)
                    TLabel(text: "CAPTURE · \(capture)", color: T3.accent)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
    }

    // MARK: - Capture / commit

    /// Human-readable summary of the state we'd capture for this accessory.
    private func captureLabel(for accessory: Accessory) -> String? {
        switch accessory.category {
        case .light:
            if accessory.isOn == true, let b = accessory.brightness {
                return "BRIGHTNESS \(Int(b * 100))%"
            }
            return accessory.isOn == true ? "ON" : "OFF"
        case .thermostat:
            if let c = accessory.currentTemperature {
                return "TARGET \(Int(c))°"
            }
            return "MODE"
        case .speaker:
            return accessory.playbackState == .playing ? "PLAY" : "PAUSE"
        case .television:
            return accessory.isOn == true ? "ON" : "OFF"
        default:
            guard let on = accessory.isOn else { return nil }
            return on ? "ON" : "OFF"
        }
    }

    /// Build a `SceneAction` matching the captureLabel decision tree.
    private func captureCommand(for accessory: Accessory) -> AccessoryCommand? {
        switch accessory.category {
        case .light:
            if accessory.isOn == true, let b = accessory.brightness {
                return .setBrightness(b)
            }
            return .setPower(accessory.isOn ?? false)
        case .thermostat:
            if let c = accessory.currentTemperature {
                return .setTargetTemperature(c)
            }
            return nil
        case .speaker:
            return accessory.playbackState == .playing ? .play : .pause
        case .television:
            return .setPower(accessory.isOn ?? false)
        default:
            guard let on = accessory.isOn else { return nil }
            return .setPower(on)
        }
    }

    private func commitScene() {
        let trimmed = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let actions: [SceneAction] = enabledDeviceIDs.compactMap { id in
            guard let accessory = registry.allAccessories.first(where: { $0.id == id }),
                  let command = captureCommand(for: accessory)
            else { return nil }
            return SceneAction(accessoryID: id, command: command)
        }

        if let existing = editingScene {
            let updated = HCScene(
                id: existing.id,
                name: trimmed,
                iconSystemName: selectedIcon,
                actions: actions
            )
            sceneStore.update(updated)
        } else {
            let scene = HCScene(
                name: trimmed,
                iconSystemName: selectedIcon,
                actions: actions
            )
            sceneStore.add(scene)
        }
        dismiss()
    }

    // MARK: - Icon mapping

    private func icon(for category: Accessory.Category) -> String {
        switch category {
        case .light: return "lightbulb.fill"
        case .thermostat: return "thermometer"
        case .lock: return "lock.fill"
        case .speaker: return "music.note"
        case .television: return "tv.fill"
        case .camera: return "camera.fill"
        case .sensor: return "sensor.tag.radiowaves.forward.fill"
        case .smokeAlarm: return "flame.fill"
        case .switch: return "switch.2"
        case .outlet: return "powerplug.fill"
        case .fan: return "fan.fill"
        case .blinds: return "blinds.horizontal.closed"
        case .other: return "circle.grid.2x2"
        }
    }
}

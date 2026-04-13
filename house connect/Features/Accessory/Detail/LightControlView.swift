//
//  LightControlView.swift
//  house connect
//
//  Bespoke detail screen for smart bulbs (and anything else that lands
//  on `Accessory.Category.light`). Matches Pencil node `kNqSI`.
//
//  Layout, top to bottom:
//    • Shared `DeviceDetailHeader` (back button + name + room + power pill)
//    • Big white hero card:
//         - Huge number + "%" + "Brightness" label
//         - 12-bar chunky visualizer — the primary interaction. Tap or
//           drag to set brightness; each "bar" represents 1/12th of
//           the 0-100 range. Feels much more physical than a thin
//           slider and matches the Pencil comp's hit-target philosophy.
//         - 0% / 50% / 100% scale labels underneath
//    • Color Temperature section — horizontal gradient bar (warm
//      orange → neutral white → cool blue) with a round draggable
//      thumb. Kelvin shown in the header; mireds are what we actually
//      command the provider with (converted on the fly).
//    • Quick Presets row — 4 chips: Reading / Relaxed / Focus / Party.
//      Each preset is a (brightness, kelvin) pair; tapping one fires
//      two commands (setBrightness, setColorTemperature) and locally
//      highlights the chip as "active". The active-state is a soft
//      match — we diff the current bulb state against each preset
//      and highlight whichever one fits within a small tolerance.
//    • Schedule card — **stub** for now. The Pencil design shows a
//      card with two rows ("Turn on 6:30 AM" / "Turn off 11:00 PM")
//      but the app doesn't have a per-device schedule concept yet
//      (Phase 3b automations land there). The card is rendered with
//      placeholder copy so the layout is complete, but the rows are
//      non-interactive with a tiny "(coming soon)" hint.
//
//  Why this isn't in `AccessoryDetailView`: the generic form-based
//  view still handles switches, outlets, locks, fans, blinds, and
//  "other" — categories that share no bespoke layout. Lights are
//  the single largest category by device count and the Pencil comp
//  gives them a first-class screen; anything less would feel flat.
//
//  Unit note: `Capability.brightness` is 0.0...1.0 and
//  `Capability.colorTemperature` is in MIREDS (not Kelvin). We
//  convert to/from Kelvin for display since the Pencil design uses
//  Kelvin in the value label ("4200K"), which is what users
//  instinctively recognize. Conversion is `kelvin = 1_000_000 / mireds`
//  both ways — lossy at the extremes, but the range we expose
//  (2700K ↔ 6500K) is well within a single mired rounding error.
//

import SwiftUI

struct LightControlView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    /// Draft brightness while the user is touch-dragging the bar row.
    /// We show this live for a responsive feel, then flush on
    /// gesture end so we don't hammer the provider with one
    /// `.setBrightness` per pixel of drag.
    @State private var brightnessDraft: Double?

    /// Same pattern for the color-temp slider.
    @State private var kelvinDraft: Double?

    /// Last error, surfaced as an inline banner at the top of the
    /// content so a failed command is visible without stealing focus.
    @State private var errorMessage: String?

    @State private var showRemoveConfirmation = false
    @State private var isRemoving = false

    @Environment(\.dismiss) private var dismiss

    // Color temp range exposed in the UI. Matches the Pencil comps'
    // visible gradient endpoints (warm incandescent → daylight) and
    // keeps us comfortably inside the `~140 ... 500` mired range
    // `Capability.colorTemperature` documents.
    private let kelvinRange: ClosedRange<Double> = 2700...6500

    // Tolerance used when deciding if a quick-preset is "currently
    // active". Brightness is normalized 0-1, so 0.05 = 5%.
    // Kelvin tolerance is 200 — bigger than the user can see.
    private let brightnessTolerance: Double = 0.05
    private let kelvinTolerance: Double = 200

    // MARK: - Lookups

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        // Broken up into locals because a one-liner closure that
        // references two different `.provider` accesses (one off
        // `Room`, one off `AccessoryID`) makes Swift's type-checker
        // slow enough to flag in SourceKit.
        let providerID = accessory.id.provider
        let match = registry.allRooms.first { room in
            room.id == roomID && room.provider == providerID
        }
        return match?.name
    }

    // Live values read from capabilities, with the user's in-flight
    // draft shadowing them if a drag is in progress. Written as
    // explicit guards rather than nil-coalescing chains because
    // `Accessory.brightness` returns `Double?`, which combines with
    // `@State var brightnessDraft: Double?` into a nested optional
    // that makes Swift's type-checker unhappy in a one-liner.
    private var currentBrightness: Double {
        if let draft = brightnessDraft { return draft }
        return accessory?.brightness ?? 0
    }

    private var currentKelvin: Double {
        if let draft = kelvinDraft { return draft }
        guard let mireds = currentMireds else { return 4200 }
        return 1_000_000 / Double(mireds)
    }

    private var currentMireds: Int? {
        guard let accessory else { return nil }
        if case .colorTemperature(let m) = accessory.capability(of: .colorTemperature) {
            return m
        }
        return nil
    }

    /// `true` when the bulb exposes a color-temperature capability —
    /// hides the entire Color Temperature section for white-only
    /// bulbs that would otherwise render a dead slider.
    private var supportsColorTemperature: Bool {
        accessory?.capability(of: .colorTemperature) != nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            if let accessory {
                ScrollView {
                    VStack(spacing: Theme.space.sectionGap) {
                        DeviceDetailHeader(
                            title: accessory.name,
                            subtitle: roomName,
                            isOn: accessory.isOn,
                            onTogglePower: { on in
                                Task { await send(.setPower(on)) }
                            }
                        )
                        .padding(.top, 8)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("\(accessory.name) light controls")

                        if !accessory.isReachable {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Device offline — controls disabled")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.orange)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }

                        if let errorMessage {
                            errorBanner(errorMessage)
                        }

                        brightnessHeroCard
                        if supportsColorTemperature {
                            colorTemperatureSection
                        }
                        quickPresetsSection
                        scheduleSection
                        removeDeviceButton
                    }
                    .padding(.horizontal, Theme.space.screenHorizontal)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "Light unavailable",
                    systemImage: "lightbulb.slash",
                    description: Text("This device is no longer reported by its provider.")
                )
                .accessibilityLabel("Light unavailable. This device is no longer reported by its provider.")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Brightness hero card

    /// The big white card at the top. Huge numeric readout + 12-bar
    /// visualizer + scale labels. The 12-bar row is the whole point
    /// of this screen — it's a big chunky hit target that reads as
    /// "tap a bar" rather than "find the thin handle on a slider".
    private var brightnessHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            valueDisplay
            BarVisualizer(value: currentBrightness) { newValue in
                brightnessDraft = newValue
            } onEnded: { finalValue in
                brightnessDraft = nil
                Task { await send(.setBrightness(finalValue)) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Brightness slider")
            .accessibilityValue("\(Int((currentBrightness * 100).rounded())) percent")
            .accessibilityHint("Tap or drag to adjust brightness")
            .accessibilityAddTraits(.allowsDirectInteraction)
            scaleLabels
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(Theme.color.cardFill)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    private var valueDisplay: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(Int((currentBrightness * 100).rounded()))")
                    .font(.system(size: 48, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.color.title)
                Text("%")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.color.muted)
            }
            Text("Brightness")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        // monospacedDigit keeps the big number from jumping around
        // as the drag changes the width of each glyph.
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int((currentBrightness * 100).rounded())) percent")
    }

    private var scaleLabels: some View {
        HStack {
            Text("0%")
            Spacer()
            Text("50%")
            Spacer()
            Text("100%")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(Theme.color.muted)
        .accessibilityHidden(true)
    }

    // MARK: - Color temperature section

    /// Gradient bar + draggable thumb. The gradient goes from warm
    /// (2700K-ish) on the left through neutral white in the middle
    /// to cool (6500K-ish) on the right — matching what users expect
    /// from every other lighting app. The thumb is a white circle
    /// with a thick accent-colored stroke, pinned to a 32pt-tall bar.
    private var colorTemperatureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Color Temperature")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Spacer()
                Text("\(Int(currentKelvin.rounded()))K")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.color.muted)
            }

            ColorTempSlider(
                kelvin: currentKelvin,
                range: kelvinRange
            ) { newKelvin in
                kelvinDraft = newKelvin
            } onEnded: { finalKelvin in
                kelvinDraft = nil
                let mireds = Int((1_000_000 / finalKelvin).rounded())
                Task { await send(.setColorTemperature(mireds)) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Color temperature slider")
            .accessibilityValue("\(Int(currentKelvin.rounded())) Kelvin")
            .accessibilityHint("Drag to adjust color temperature from warm to cool")
            .accessibilityAddTraits(.allowsDirectInteraction)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color Temperature")
    }

    // MARK: - Quick presets

    /// Four preset chips. Each preset is a (brightness 0-1, kelvin)
    /// tuple; tapping one fires the corresponding brightness and
    /// color-temperature commands back-to-back. The chip highlights
    /// (filled accent) when the current bulb state matches the
    /// preset within a small tolerance, so the user can tell at a
    /// glance which scene their bulb is sitting in.
    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Presets")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.color.title)
            HStack(spacing: 10) {
                ForEach(Self.presets) { preset in
                    PresetChip(
                        preset: preset,
                        isActive: isActive(preset)
                    ) {
                        apply(preset)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick Presets")
    }

    private func isActive(_ preset: LightPreset) -> Bool {
        let b = currentBrightness
        let k = currentKelvin
        return abs(b - preset.brightness) <= brightnessTolerance
            && (!supportsColorTemperature || abs(k - preset.kelvin) <= kelvinTolerance)
    }

    private func apply(_ preset: LightPreset) {
        Task {
            // Fire brightness first so the user sees the hero card
            // update before the temperature animation — it feels
            // more responsive than waiting for both to land at once.
            await send(.setBrightness(preset.brightness))
            if supportsColorTemperature {
                let mireds = Int((1_000_000 / preset.kelvin).rounded())
                await send(.setColorTemperature(mireds))
            }
        }
    }

    /// Preset catalog. Kelvin values picked to match common lighting
    /// scenarios (incandescent read = 6500 / 2700 / 5000 / 3500).
    /// Icons are SF Symbols that pattern-match the Pencil comp's
    /// Lucide icons as closely as the SF Symbol set allows.
    private static let presets: [LightPreset] = [
        LightPreset(id: "reading",
                    name: "Reading",
                    icon: "book.fill",
                    brightness: 1.0,
                    kelvin: 6500),
        LightPreset(id: "relaxed",
                    name: "Relaxed",
                    icon: "sofa.fill",
                    brightness: 0.4,
                    kelvin: 2700),
        LightPreset(id: "focus",
                    name: "Focus",
                    icon: "scope",
                    brightness: 1.0,
                    kelvin: 5000),
        LightPreset(id: "party",
                    name: "Party",
                    icon: "party.popper.fill",
                    brightness: 0.8,
                    kelvin: 3500),
    ]

    // MARK: - Schedule (stub)

    /// Placeholder schedule card. Matches the Pencil comp's layout
    /// but doesn't wire anything up yet — per-device schedules are
    /// a Phase 3b automation story, not something HomeKit or
    /// SmartThings expose through our current provider protocol.
    /// Rendering the card anyway keeps the screen visually
    /// complete; the "coming soon" hint makes the stub honest.
    /// Schedule card — shows a "coming soon" placeholder rather than
    /// hardcoded times that could mislead users into thinking schedules
    /// are functional. Per-device light schedules require automation
    /// infrastructure that doesn't exist yet (Phase 3b).
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Schedule")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Spacer()
            }

            VStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.color.muted)
                Text("Light schedules coming soon")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.color.subtitle)
                Text("Set sunrise/sunset automations once per-device scheduling ships in a future update.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.color.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(Theme.color.cardFill)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Schedule")
            .accessibilityValue("Coming soon")
            .accessibilityHint("Light schedules will be available in a future update")
        }
    }


    // MARK: - Remove device

    private var removeDeviceButton: some View {
        Button(role: .destructive) {
            showRemoveConfirmation = true
        } label: {
            HStack {
                if isRemoving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.red)
                }
                Text("Remove Device")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "trash")
                    .font(.system(size: 14))
            }
            .foregroundStyle(.red)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(isRemoving)
        .accessibilityLabel(isRemoving ? "Removing device" : "Remove Device")
        .accessibilityHint("Double tap to remove this light from its ecosystem")
        .accessibilityAddTraits(.isButton)
        .confirmationDialog(
            "Remove \(accessory?.name ?? "this device")?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await performRemove() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will unpair the device from \(accessory?.id.provider.displayLabel ?? "its ecosystem"). You can re-add it later from the Add tab.")
        }
    }

    private func performRemove() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await registry.removeAccessory(accessoryID)
            dismiss()
        } catch {
            errorMessage = "Could not remove device: \(error.localizedDescription)"
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.color.title)
            Spacer()
            Button("Dismiss") { errorMessage = nil }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.primary)
                .accessibilityLabel("Dismiss error")
                .accessibilityHint("Double tap to dismiss this error message")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.chip, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Command dispatch

    /// Single choke-point for commands so error handling stays in
    /// one place. Provider errors land in `errorMessage` and render
    /// in the banner at the top of the scroll view.
    private func send(_ command: AccessoryCommand) async {
        do {
            try await registry.execute(command, on: accessoryID)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}

// MARK: - Preset model

private struct LightPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    /// 0.0 ... 1.0
    let brightness: Double
    /// Kelvin (user-facing units). Converted to mireds on command.
    let kelvin: Double
}

// MARK: - Preset chip

/// One of the four tiles in the Quick Presets row. Filled (active)
/// renders as `Theme.color.primary` with white glyph + label; inactive
/// renders as a soft card fill with secondary text. All four live in
/// an equal-width HStack so the row always fills the parent width
/// regardless of screen size.
private struct PresetChip: View {
    let preset: LightPreset
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(preset.name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isActive ? .white : Theme.color.subtitle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                    .fill(isActive ? Theme.color.primary : Theme.color.cardFill)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name) preset")
        .accessibilityValue(isActive ? "Active" : "Inactive")
        .accessibilityHint("Double tap to apply \(preset.name) lighting scene")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - 12-bar brightness visualizer

/// Twelve chunky rounded-rect "bars" laid out horizontally. Bars
/// whose index is <= the current fill count are drawn in accent
/// purple; the rest are a soft surface-secondary gray. The whole
/// row is one giant hit target: a tap anywhere picks the bar under
/// the finger, a drag updates continuously. The parent view shows
/// the live draft value in the big number above, then flushes to
/// the provider on gesture end.
///
/// Why bars instead of a slider? — matches the Pencil comp, and
/// makes "give me 25%" a 1-tap target instead of "drag the little
/// handle a precise distance".
private struct BarVisualizer: View {
    let value: Double
    /// Called continuously during drag with the in-progress value.
    let onChange: (Double) -> Void
    /// Called once when the gesture ends so the parent can fire a
    /// command without spamming the provider during the drag.
    let onEnded: (Double) -> Void

    private let barCount: Int = 12
    private let barGap: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let barW = (totalW - barGap * CGFloat(barCount - 1)) / CGFloat(barCount)
            // Fill count: round UP so tapping the middle of bar N
            // fills through bar N. Clamped to 0...barCount.
            let filled = max(0, min(barCount, Int((value * Double(barCount)).rounded())))

            HStack(spacing: barGap) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index < filled ? Theme.color.primary : Theme.color.divider)
                        .frame(width: barW)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let x = max(0, min(totalW, g.location.x))
                        let v = totalW > 0 ? Double(x / totalW) : 0
                        onChange(v)
                    }
                    .onEnded { g in
                        let x = max(0, min(totalW, g.location.x))
                        let v = totalW > 0 ? Double(x / totalW) : 0
                        onEnded(v)
                    }
            )
        }
        .frame(height: 40)
    }
}

// MARK: - Color temperature slider

/// Horizontal gradient bar — warm orange → white → cool blue — with
/// a round draggable thumb. The thumb's x-position is derived from
/// the current Kelvin value projected onto `range`. Dragging updates
/// the live draft; letting go flushes a `.setColorTemperature`
/// command with the mired-converted final value.
private struct ColorTempSlider: View {
    let kelvin: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void
    let onEnded: (Double) -> Void

    private let barHeight: CGFloat = 32
    private let thumbSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let trackW = geo.size.width
            let span = range.upperBound - range.lowerBound
            let clamped = min(max(kelvin, range.lowerBound), range.upperBound)
            let normalized = span > 0 ? (clamped - range.lowerBound) / span : 0
            let thumbX = CGFloat(normalized) * (trackW - thumbSize)

            ZStack(alignment: .leading) {
                // Gradient track — warm on the left (lower Kelvin,
                // higher mireds) through white in the middle to
                // cool on the right. Rotation is implicit because
                // the gradient is horizontal by default.
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.60, blue: 0.20),  // ~2700K
                        Color(red: 1.00, green: 0.97, blue: 0.90),  // ~4200K neutral
                        Color(red: 0.60, green: 0.80, blue: 1.00),  // ~6500K
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: barHeight)
                .clipShape(Capsule())

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .stroke(Theme.color.primary, lineWidth: 3)
                    )
                    .offset(x: thumbX, y: 0)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let x = max(0, min(trackW, g.location.x))
                        let n = trackW > 0 ? Double(x / trackW) : 0
                        let k = range.lowerBound + n * span
                        onChange(k)
                    }
                    .onEnded { g in
                        let x = max(0, min(trackW, g.location.x))
                        let n = trackW > 0 ? Double(x / trackW) : 0
                        let k = range.lowerBound + n * span
                        onEnded(k)
                    }
            )
        }
        .frame(height: barHeight)
    }
}

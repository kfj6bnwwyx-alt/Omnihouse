//
//  FrameTVDetailView.swift
//  house connect
//
//  Bespoke detail screen for the Samsung Frame TV. Matches Pencil node
//  `GrzJY`. SCAFFOLD ONLY — the Samsung Frame TV provider is Phase 8.
//  Not currently reachable from `DeviceDetailView` because our unified
//  vocabulary does not yet distinguish "TV" from the generic `.speaker`
//  category. When the Frame TV provider lands:
//    - Add `.television` to `Accessory.Category`.
//    - Route that category here from `DeviceDetailView.routedView`.
//    - Add HDMI-source / Art-mode commands to `AccessoryCommand`.
//    - Pipe `currentInput` into a capability case.
//
//  Until then this file exists so the design is captured in code and we
//  don't have to remember what went where. It compiles, previews, and
//  reads the accessory off the registry like every other detail screen.
//

import SwiftUI

struct FrameTVDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    @State private var selectedInput: Input = .hdmi1
    @State private var brightness: Double = 0.5
    @State private var colorTone: Double = 0.5

    enum Input: String, CaseIterable, Hashable {
        case hdmi1 = "HDMI 1"
        case hdmi2 = "HDMI 2"
        case airplay = "AirPlay"
        case artMode = "Art Mode"

        var systemImage: String {
            switch self {
            case .hdmi1, .hdmi2: "cable.connector"
            case .airplay: "airplayvideo"
            case .artMode: "photo.artframe"
            }
        }
    }

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String? {
        guard let accessory, let roomID = accessory.roomID else { return nil }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name
    }

    var body: some View {
        ZStack {
            Theme.color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    DeviceDetailHeader(
                        title: accessory?.name ?? "The Frame",
                        subtitle: roomName,
                        isOn: accessory?.isOn ?? false,
                        onTogglePower: { _ in
                            // Wire to .setPower when Frame TV provider lands.
                        }
                    )
                    .padding(.top, 8)

                    artPreviewCard
                    artCaptionCard
                    inputsCard
                    quickButtonsCard
                    slidersCard
                    RemoveDeviceSection(accessoryID: accessoryID)
                }
                .padding(.horizontal, Theme.space.screenHorizontal)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Art preview

    private var artPreviewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.18), Color(white: 0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            // Starry-night-ish painterly mood: radial halo + swirl glyph
            // keeps the hero feeling like a framed artwork rather than a
            // TV signal test pattern.
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.32, blue: 0.58).opacity(0.55),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )

            VStack(spacing: 10) {
                Image(systemName: "swirl.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.82, blue: 0.38),
                                Color(red: 0.62, green: 0.72, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Starry Night")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text("Vincent van Gogh")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    // MARK: - Art caption

    /// Small subtitle row under the hero that mirrors the Pencil layout:
    /// a status pill ("Art Mode · On") and the piece/artist label.
    private var artCaptionCard: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Art Mode · On")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Theme.color.iconChipFill)
            )

            Spacer(minLength: 8)

            Text("Van Gogh — Starry Night")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.color.subtitle)
                .lineLimit(1)
        }
        .hcCard()
    }

    // MARK: - Inputs

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Input Source")
                .font(Theme.font.cardTitle)
                .foregroundStyle(Theme.color.title)

            // Horizontal scroll so the pill row never clips on small
            // phones even if we add more inputs later.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Input.allCases, id: \.self) { input in
                        inputChip(input)
                    }
                }
            }
        }
        .hcCard()
    }

    private func inputChip(_ input: Input) -> some View {
        let selected = selectedInput == input
        return Button {
            selectedInput = input
        } label: {
            HStack(spacing: 6) {
                Image(systemName: input.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(input.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? .white : Theme.color.subtitle)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? Theme.color.primary : Theme.color.iconChipFill)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick buttons (power/vol-/vol+/mute)

    /// Pencil GrzJY shows a horizontal row of four circular remote-style
    /// buttons. Re-implemented as round filled IconChips so it reads as a
    /// hardware remote rather than four labeled tiles.
    private var quickButtonsCard: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            circleButton(icon: "power", tint: Theme.color.primary)
            circleButton(icon: "speaker.wave.1.fill")
            circleButton(icon: "speaker.wave.3.fill")
            circleButton(icon: "speaker.slash.fill")
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .hcCard(padding: 0)
    }

    private func circleButton(icon: String, tint: Color? = nil) -> some View {
        Button {
            // Hook up to real commands when Frame TV provider lands.
        } label: {
            ZStack {
                Circle()
                    .fill(tint ?? Theme.color.iconChipFill)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint == nil ? Theme.color.title : .white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sliders

    private var slidersCard: some View {
        VStack(spacing: 14) {
            sliderRow(icon: "sun.max.fill",
                      label: "Brightness",
                      value: $brightness)
            sliderRow(icon: "paintpalette.fill",
                      label: "Color Tone",
                      value: $colorTone)
        }
        .hcCard()
    }

    private func sliderRow(
        icon: String,
        label: String,
        value: Binding<Double>
    ) -> some View {
        HStack(spacing: 12) {
            IconChip(systemName: icon, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color.title)
                Slider(value: value, in: 0...1)
                    .tint(Theme.color.primary)
            }
        }
    }
}

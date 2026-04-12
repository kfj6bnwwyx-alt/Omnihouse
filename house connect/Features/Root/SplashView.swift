//
//  SplashView.swift
//  house connect
//
//  Animated launch screen (Pencil `QXNHS`). Shows for ~1.8s while the
//  provider registry fires its opening scans in the background, then
//  fades into `RootTabView`.
//
//  The Pencil comp uses rendered 3D isometric icons on a deep-blue
//  gradient — we don't have those art assets, so we approximate with
//  a symmetrical grid of SF Symbols representing the supported device
//  categories (house, lightbulb, camera, lock, thermostat, speaker,
//  fan, outlet) faded behind the brand chrome. A centered, glowing
//  lightbulb sits on top as the focal point, matching the comp's
//  lit-bulb silhouette.
//
//  The grid is intentionally desaturated into the background — it's
//  decoration, not an affordance. The `House Connect` wordmark and
//  "Your smart home, simplified" tagline are the hero. A subtle
//  scale + opacity fade gives the splash a brief entrance so the
//  jump into the TabView doesn't feel abrupt.
//
//  Lifecycle: parent `RootContainerView` owns the `isActive` flag and
//  swaps from SplashView → RootTabView via a .transition. We don't
//  block any async work on the splash — the registry's `.task`
//  on RootTabView still runs the moment the switch happens; the
//  splash is pure chrome, not a loading gate.
//

import SwiftUI

struct SplashView: View {

    /// Drives the entrance animation. Starts at 0 (pre-animate), flips
    /// to 1 on first render so the hero bulb scales up from 0.85.
    @State private var appeared = false

    var body: some View {
        ZStack {
            backgroundGradient
            iconGrid
            brandHero
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    /// Deep navy-to-midnight gradient. Approximates the Pencil's
    /// dark-blue base; the numbers were eyeballed off the screenshot.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.22, blue: 0.42),  // ~#283870
                Color(red: 0.08, green: 0.11, blue: 0.22),  // ~#141C38
                Color(red: 0.04, green: 0.06, blue: 0.14)   // ~#0A1024
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Decorative icon grid

    /// 4-column grid of faded SF Symbols representing device types.
    /// Kept slightly off-center and with varying opacity so it reads
    /// as an isometric-ish scatter rather than a rigid grid.
    ///
    /// The column count and symbol set are tuned against a 390pt
    /// iPhone width — dense enough to fill the background without
    /// stealing focus from the hero text.
    private var iconGrid: some View {
        GeometryReader { geo in
            let columns = 4
            let spacing: CGFloat = 22
            let cellSize = (geo.size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
            VStack(spacing: spacing) {
                ForEach(iconRows.indices, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(iconRows[row].indices, id: \.self) { col in
                            iconTile(iconRows[row][col], size: cellSize)
                        }
                    }
                }
            }
            .padding(spacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 0.22 : 0)
            .animation(.easeOut(duration: 0.9), value: appeared)
        }
    }

    /// Grid rows. Read top-to-bottom, left-to-right. Hand-picked so
    /// no two identical glyphs sit adjacent — mirrors the diversity
    /// of the 3D render in the Pencil comp.
    private var iconRows: [[String]] {
        [
            ["hifispeaker.fill", "lock.fill", "house.fill", "video.fill"],
            ["lightbulb.fill", "thermometer.medium", "hifispeaker.fill", "lock.fill"],
            ["house.fill", "lightbulb.fill", "video.fill", "fan.fill"],
            ["power", "hifispeaker.fill", "lock.fill", "house.fill"],
            ["lightbulb.fill", "thermometer.medium", "house.fill", "video.fill"],
            ["hifispeaker.fill", "fan.fill", "power", "lock.fill"]
        ]
    }

    private func iconTile(_ systemName: String, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    // MARK: - Brand hero (lightbulb + wordmark + tagline)

    private var brandHero: some View {
        VStack(spacing: 14) {
            Spacer()
            glowingBulb
            Text("House Connect")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
            Text("Your smart home, simplified")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .opacity(appeared ? 1 : 0)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)
    }

    /// Centered lit bulb — the single "lit" node in the Pencil comp.
    /// A soft radial halo sits beneath the glyph so the bulb reads
    /// as the light source for the rest of the scatter.
    private var glowingBulb: some View {
        ZStack {
            // Warm halo. Offset slightly larger than the glyph so the
            // falloff spills past the icon edge.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.38).opacity(0.55),
                            Color(red: 1.0, green: 0.82, blue: 0.38).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 6)

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.92, blue: 0.55),
                            Color(red: 1.0, green: 0.72, blue: 0.30)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.38).opacity(0.7),
                        radius: 24, x: 0, y: 0)
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
    }
}

//
//  WatchHomeView.swift
//  HouseConnectWatch
//
//  Pencil `ZNJj1` — Apple Watch home screen. Shows "House Connect" title
//  with a house icon, then a 2x2 grid of category summary tiles:
//    - Lights (count on, bulb icon)
//    - Climate (current temp, thermometer icon)
//    - Locks (status, lock icon)
//    - Media (playback status, speaker icon)
//
//  Each tile taps through to a device list for that category (not yet
//  implemented — placeholder navigation). The dark background and accent
//  colors match the Pencil comp's Watch-native look.
//
//  NOTE: This file requires a WatchKit App target to be created in Xcode.
//  Until then, it won't compile as part of any target. To create the
//  target: File → New → Target → watchOS → App, name it
//  "HouseConnectWatch", and add this file to its target membership.
//

import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("House Connect")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 4)

                // 2x2 Category grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    categoryTile(
                        icon: "lightbulb.fill",
                        label: "Lights",
                        value: "3 On",
                        color: Color(red: 0.98, green: 0.82, blue: 0.3)
                    )
                    categoryTile(
                        icon: "thermometer.medium",
                        label: "Climate",
                        value: "72°F",
                        color: Color(red: 0.31, green: 0.27, blue: 0.91)
                    )
                    categoryTile(
                        icon: "lock.fill",
                        label: "Locks",
                        value: "Locked",
                        color: Color(red: 0.6, green: 0.4, blue: 0.9)
                    )
                    categoryTile(
                        icon: "hifispeaker.fill",
                        label: "Media",
                        value: "Playing",
                        color: Color(red: 0.31, green: 0.27, blue: 0.91)
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color.black)
    }

    private func categoryTile(
        icon: String,
        label: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.12))
        )
    }
}

#if DEBUG
struct WatchHomeView_Previews: PreviewProvider {
    static var previews: some View {
        WatchHomeView()
            .previewDevice("Apple Watch Series 10 (46mm)")
    }
}
#endif

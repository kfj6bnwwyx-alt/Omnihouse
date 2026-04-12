//
//  WatchDeviceDetailView.swift
//  HouseConnectWatch
//
//  Pencil `9e4YX` — Apple Watch device detail for a light. Shows the
//  device name with a bulb icon, a power toggle, a brightness slider
//  with percentage readout, and On/Off status text.
//
//  This is a representative example for the Watch UI language — other
//  device types (thermostat, lock, speaker) will follow the same
//  compact card pattern once the Watch app matures.
//
//  NOTE: Requires WatchKit App target. See WatchHomeView.swift for
//  setup instructions.
//

import SwiftUI

struct WatchDeviceDetailView: View {
    let deviceName: String

    @State private var isOn: Bool = true
    @State private var brightness: Double = 75

    private let accentColor = Color(red: 0.31, green: 0.27, blue: 0.91)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header: icon + name
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOn ? accentColor : .gray)
                    Text(deviceName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Power toggle
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(accentColor)

                // Brightness section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brightness")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))

                    // Segmented brightness bar
                    GeometryReader { proxy in
                        let totalSegments = 12
                        let filledCount = Int(brightness / 100.0 * Double(totalSegments))
                        let segmentWidth = (proxy.size.width - CGFloat(totalSegments - 1) * 2) / CGFloat(totalSegments)

                        HStack(spacing: 2) {
                            ForEach(0..<totalSegments, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(i < filledCount ? accentColor : Color(white: 0.2))
                                    .frame(width: segmentWidth)
                            }
                        }
                    }
                    .frame(height: 16)

                    // Value + status
                    HStack {
                        Text("\(Int(brightness))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(isOn ? "On" : "Off")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isOn ? accentColor : .gray)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color.black)
    }
}

#if DEBUG
struct WatchDeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WatchDeviceDetailView(deviceName: "Living Room Light")
            .previewDevice("Apple Watch Series 10 (46mm)")
    }
}
#endif

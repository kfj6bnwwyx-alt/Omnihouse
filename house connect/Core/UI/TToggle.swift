//
//  TToggle.swift
//  house connect
//
//  Shared T3 toggle — square RoundedRectangle track with a sliding
//  square thumb. Extracted 2026-04-18 so T3NotificationPreferencesView,
//  T3AppearanceView, and future settings rows share one primitive.
//
//  ON  = T3.ink track, T3.page thumb
//  OFF = T3.rule track, T3.page thumb
//
//  Geometry: 44×26 track, 22×22 thumb, 2pt inset, 0-radius corners
//  to stay consistent with the "no rounded cards, hairlines only"
//  T3 rule set.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TToggle: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackSize = CGSize(width: 44, height: 26)
    private let thumbSide: CGFloat = 22
    private let inset: CGFloat = 2

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            if reduceMotion {
                isOn.toggle()
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    isOn.toggle()
                }
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 0)
                    .fill(isOn ? T3.ink : T3.rule)
                    .frame(width: trackSize.width, height: trackSize.height)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isOn)

                Rectangle()
                    .fill(T3.page)
                    .frame(width: thumbSide, height: thumbSide)
                    .padding(.horizontal, inset)
            }
            .frame(width: trackSize.width, height: trackSize.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

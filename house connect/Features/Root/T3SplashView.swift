//
//  T3SplashView.swift
//  house connect
//
//  T3/Swiss splash screen — Braun T3 power-dot + tight logotype.
//  Minimal: orange dot, "house connect." wordmark, loading progress.
//  Matches the Claude Design handoff (T3Splash component).
//

import SwiftUI

struct T3SplashView: View {
    @State private var progress: Int = 0
    private let total = 10

    var body: some View {
        ZStack {
            T3.page.ignoresSafeArea()

            VStack {
                // Top meta row
                HStack {
                    TLabel(text: "House Connect")
                    Spacer()
                    TLabel(text: "V 1.0")
                }

                Spacer()

                // Centerpiece: orange power dot + logotype
                VStack(alignment: .leading, spacing: 0) {
                    TDot(size: 16)

                    Text("house\nconnect.")
                        .font(T3.inter(44, weight: .medium))
                        .tracking(-1.4)
                        .lineSpacing(0)
                        .foregroundStyle(T3.ink)
                        .padding(.top, 22)

                    Text("A calm controller for everything at home.\nSeventeen devices, six rooms.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(4)
                        .padding(.top, 14)
                        .frame(maxWidth: 240, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Bottom progress — minimal tick bar
                VStack(spacing: 10) {
                    TRule()

                    HStack {
                        TLabel(text: "Loading")
                        Spacer()

                        // Tick progress bar
                        HStack(spacing: 3) {
                            ForEach(0..<total, id: \.self) { i in
                                Rectangle()
                                    .fill(i < progress ? T3.ink : T3.rule)
                                    .frame(width: 6, height: 2)
                            }
                        }

                        Spacer()

                        TLabel(text: String(format: "%02d / %02d", progress, total))
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 46)
        }
        .onAppear {
            // Animate progress ticks
            for i in 1...total {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    progress = i
                }
            }
        }
    }
}

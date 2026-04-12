//
//  HelpFAQView.swift
//  house connect
//
//  "Help & FAQ" screen reached from Settings → Support → Help & FAQ.
//  Covers common setup questions, troubleshooting tips, and ecosystem-
//  specific guidance. Pure static content — no network needed.
//

import SwiftUI

struct HelpFAQView: View {
    @State private var expandedQuestion: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space.sectionGap) {
                header
                    .padding(.top, 8)

                faqSection(title: "GETTING STARTED", items: gettingStartedItems)
                faqSection(title: "DEVICES & CONTROLS", items: devicesItems)
                faqSection(title: "SCENES & AUTOMATIONS", items: scenesItems)
                faqSection(title: "TROUBLESHOOTING", items: troubleshootingItems)

                contactCard
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space.screenHorizontal)
        }
        .background(Theme.color.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        SettingsSubpageHeader(title: "Help & FAQ", subtitle: "Common questions answered")
    }

    // MARK: - FAQ section

    @ViewBuilder
    private func faqSection(title: String, items: [(question: String, answer: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color.subtitle)
                .tracking(0.8)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(items, id: \.question) { item in
                    FAQRow(
                        question: item.question,
                        answer: item.answer,
                        isExpanded: expandedQuestion == item.question,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedQuestion = expandedQuestion == item.question ? nil : item.question
                            }
                        }
                    )
                }
            }
            .hcCard(padding: 0)
        }
    }

    // MARK: - Contact card

    private var contactCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.color.iconChipFill)
                    .frame(width: 56, height: 56)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.color.iconChipGlyph)
            }
            .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Still need help?")
                    .font(Theme.font.cardTitle)
                    .foregroundStyle(Theme.color.title)
                Text("Reach out to our support team and we'll get back to you within 24 hours.")
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .hcCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Still need help? Reach out to our support team and we'll get back to you within 24 hours.")
    }

    // MARK: - FAQ content

    private var gettingStartedItems: [(question: String, answer: String)] {
        [
            (
                "How do I connect my first smart home ecosystem?",
                "Go to Settings → Connections and tap the ecosystem you want to add. HomeKit will prompt for Home access, SmartThings requires a personal access token from the SmartThings developer portal, and Sonos is discovered automatically on your local network."
            ),
            (
                "Can I use multiple ecosystems at once?",
                "Yes! House Connect is designed to unify HomeKit, SmartThings, Sonos, and Nest into a single interface. Devices from all connected ecosystems appear together on your dashboard."
            ),
            (
                "What if I only use HomeKit?",
                "That works great. House Connect uses Apple's HomeKit framework directly, so you get all your HomeKit devices with a fresh, modern interface. You can add other ecosystems later if you expand your setup."
            ),
        ]
    }

    private var devicesItems: [(question: String, answer: String)] {
        [
            (
                "Why is a device showing as offline?",
                "A device shows offline when House Connect can't reach it. Check that the device is powered on, within Wi-Fi or Bluetooth range, and that any required hubs (like a Hue Bridge or SmartThings Hub) are online."
            ),
            (
                "Why do I see the same device twice?",
                "If a device is paired with multiple ecosystems (e.g. both HomeKit and SmartThings), it may appear once per ecosystem. Switch to 'Devices' view mode on the Devices tab — it merges duplicates automatically."
            ),
            (
                "How do I remove a device?",
                "Open the device's detail screen and scroll to the bottom. Tap 'Remove Device' and confirm. For HomeKit devices, this unpairs them from your Home. For SmartThings, it deletes them from your account."
            ),
        ]
    }

    private var scenesItems: [(question: String, answer: String)] {
        [
            (
                "What are scenes?",
                "Scenes let you control multiple devices with a single tap. For example, a 'Movie Night' scene could dim the living room lights, set a color temperature, and start your Sonos playing — all at once."
            ),
            (
                "Can scenes control devices from different ecosystems?",
                "Yes! That's the main advantage of House Connect scenes over ecosystem-native ones. A single scene can control HomeKit lights, SmartThings switches, and Sonos speakers together."
            ),
        ]
    }

    private var troubleshootingItems: [(question: String, answer: String)] {
        [
            (
                "My HomeKit devices aren't showing controls",
                "Try pulling down to refresh on the Devices tab. HomeKit sometimes needs a moment to sync characteristic values after first pairing. If controls still don't appear, open the Home app briefly and return — this forces iOS to refresh the accessory cache."
            ),
            (
                "SmartThings devices are slow to respond",
                "SmartThings commands go through Samsung's cloud servers, so they'll always be slightly slower than local-network HomeKit commands. If delays are excessive (>5 seconds), check your internet connection."
            ),
            (
                "Sonos speakers disappeared from the app",
                "Sonos discovery uses local network (Bonjour). Make sure your phone is on the same Wi-Fi network as your speakers. Also check that House Connect has Local Network permission in iOS Settings → Privacy."
            ),
        ]
    }
}

// MARK: - FAQ row

private struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(question)
                        .font(Theme.font.cardTitle)
                        .foregroundStyle(Theme.color.title)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.color.muted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question)
            .accessibilityHint(isExpanded ? "Double tap to collapse answer" : "Double tap to expand answer")
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")

            if isExpanded {
                Text(answer)
                    .font(Theme.font.cardSubtitle)
                    .foregroundStyle(Theme.color.subtitle)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

//
//  HelpFAQView.swift
//  house connect
//
//  Settings → Support → Help & FAQ. T3/Swiss rewrite 2026-04-18.
//  Static content grouped into sections, each item is tap-to-expand.
//

import SwiftUI

struct HelpFAQView: View {
    @State private var expandedQuestion: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Help & FAQ.", subtitle: "Common questions answered")

                faqSection(title: "Getting started", items: gettingStartedItems)
                faqSection(title: "Devices & controls", items: devicesItems)
                faqSection(title: "Scenes & automations", items: scenesItems)
                faqSection(title: "Troubleshooting", items: troubleshootingItems)

                // Contact
                TSectionHead(title: "Still stuck", count: "")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reach out to support")
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                    Text("We read every message. Typical reply under 24 hours.")
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineSpacing(3)
                    Link(destination: URL(string: "mailto:support@example.com")!) {
                        HStack(spacing: 10) {
                            T3IconImage(systemName: "envelope.fill")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(T3.page)
                            Text("EMAIL SUPPORT")
                                .font(T3.mono(11))
                                .tracking(2)
                                .foregroundStyle(T3.page)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(T3.ink)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 16)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    @ViewBuilder
    private func faqSection(title: String, items: [FAQItem]) -> some View {
        TSectionHead(title: title, count: String(format: "%02d", items.count))
        ForEach(Array(items.enumerated()), id: \.offset) { i, item in
            t3FAQRow(item: item, isLast: i == items.count - 1)
        }
    }

    private func t3FAQRow(item: FAQItem, isLast: Bool) -> some View {
        let expanded = expandedQuestion == item.question
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    expandedQuestion = expanded ? nil : item.question
                }
            } label: {
                HStack(spacing: 12) {
                    Text(item.question)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    T3IconImage(systemName: "chevron.right")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(T3.sub)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(item.answer)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    // MARK: - Content

    private struct FAQItem {
        let question: String
        let answer: String
    }

    private var gettingStartedItems: [FAQItem] {
        [
            FAQItem(question: "How do I connect my first ecosystem?",
                    answer: "Go to Settings → Connections and tap the ecosystem you want to add. HomeKit will prompt for Home access. SmartThings needs a Personal Access Token from the SmartThings developer portal. Sonos is auto-discovered on your local Wi-Fi."),
            FAQItem(question: "Can I use multiple ecosystems at once?",
                    answer: "Yes. House Connect is designed to unify HomeKit, SmartThings, Sonos, Nest, and Home Assistant into a single interface. Devices from every connected ecosystem appear together on your dashboard."),
            FAQItem(question: "What if I only use HomeKit?",
                    answer: "That works great. House Connect uses Apple's HomeKit framework directly — you get every HomeKit accessory with a fresh interface. You can add other ecosystems later as your setup grows."),
        ]
    }

    private var devicesItems: [FAQItem] {
        [
            FAQItem(question: "Why is a device showing as offline?",
                    answer: "A device shows offline when House Connect can't reach it. Check that the device is powered on, within Wi-Fi or Bluetooth range, and that any required hubs (Hue Bridge, SmartThings Hub, etc.) are online."),
            FAQItem(question: "Why do I see the same device twice?",
                    answer: "If a device is paired with multiple ecosystems (e.g. HomeKit and SmartThings), it may appear once per ecosystem. Use 'Devices' mode on the Devices tab — it merges duplicates automatically."),
            FAQItem(question: "How do I remove a device?",
                    answer: "Open the device's detail screen and scroll to the bottom. Tap 'Remove device' and confirm. For HomeKit, this unpairs it from your Home. For SmartThings, it's deleted from your Samsung account."),
        ]
    }

    private var scenesItems: [FAQItem] {
        [
            FAQItem(question: "What are scenes?",
                    answer: "Scenes control multiple devices with a single tap. A 'Movie night' scene could dim the living-room lights, set a warmer color temperature, and pause your Sonos — all at once."),
            FAQItem(question: "Can scenes control devices from different ecosystems?",
                    answer: "Yes — this is the main advantage of House Connect scenes over vendor-native ones. A single scene can control HomeKit lights, SmartThings switches, and Sonos speakers together."),
        ]
    }

    private var troubleshootingItems: [FAQItem] {
        [
            FAQItem(question: "My HomeKit devices aren't showing controls",
                    answer: "Pull down to refresh the Devices tab. HomeKit sometimes needs a moment to sync characteristic values after pairing. If controls still don't appear, open the Home app briefly and return — this forces iOS to refresh the accessory cache."),
            FAQItem(question: "SmartThings devices are slow to respond",
                    answer: "SmartThings commands go through Samsung's cloud, so they're always slightly slower than local-network HomeKit commands. If delays exceed 5 seconds, check your internet connection."),
            FAQItem(question: "Sonos speakers disappeared",
                    answer: "Sonos discovery uses local network (Bonjour). Make sure your phone is on the same Wi-Fi as your speakers. Also check Settings → Privacy → Local Network that House Connect is granted access."),
            FAQItem(question: "Home Assistant connection keeps dropping",
                    answer: "If your local URL (e.g. 192.168.4.23:8123) becomes unreachable, House Connect falls back to the Tailscale URL you entered in HA Setup. Make sure your phone has Tailscale enabled in iOS settings."),
        ]
    }
}

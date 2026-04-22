//
//  T3ManageDeviceLinksView.swift
//  house connect
//
//  Settings → Home → Linked Devices. Lets the user manually pair an
//  accessory from one provider with the same physical device exposed by
//  another provider (e.g. "Office Lamp" from HomeKit ↔ HA
//  "light.office_main"). Once linked the Devices tab merges them into a
//  single tile when Merged mode is on.
//
//  Sections:
//   · Current links  — tap × to unlink
//   · Potential matches — pairs with same category + fuzzy name match
//   · All devices    — two-step picker for manual links
//

import SwiftUI

struct T3ManageDeviceLinksView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(DeviceLinkStore.self)  private var linkStore

    @State private var showingLinkPicker = false
    @State private var unlinkCandidate: ManualDeviceLink?
    @State private var confirmClearAll = false
    /// Flash a small confirmation after a candidate row is linked. Without
    /// this, multiple potential-match rows involving the same device appear
    /// to vanish at once, making it feel like one tap linked several pairs.
    @State private var lastLinkedToast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Linked Devices.",
                       subtitle: "Match the same device across providers")
                    .t3ScreenTopPad()

                // Current links
                TSectionHead(title: "Current links",
                             count: String(format: "%02d", linkStore.links.count))

                if linkStore.links.isEmpty {
                    T3EmptyState(
                        iconSystemName: "link.badge.plus",
                        title: "No links yet",
                        subtitle: "Link devices that appear on two providers but have different names.",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    ForEach(Array(linkStore.links.enumerated()), id: \.element.id) { i, link in
                        currentLinkRow(link, isLast: i == linkStore.links.count - 1)
                    }

                    // Escape hatch — wipe every link. Useful when stale
                    // entries from earlier test runs pile up.
                    Button {
                        confirmClearAll = true
                    } label: {
                        Text("Clear all links")
                            .font(T3.inter(13, weight: .medium))
                            .foregroundStyle(T3.danger)
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                // Potential matches (auto-detected cross-provider candidates)
                let candidates = potentialMatches
                if !candidates.isEmpty {
                    TSectionHead(title: "Potential matches",
                                 count: String(format: "%02d", candidates.count))

                    // Pair-derived stable ID. Using offset as the
                    // ForEach id caused Scenario A: after linking one
                    // pair, the list filtered, offsets shifted, and
                    // SwiftUI reused Button instances against new pair
                    // data — subsequent taps landed on the wrong pair.
                    // A single accessory can appear in multiple
                    // candidate pairs (same primary, different
                    // secondaries), so we combine both IDs.
                    let identified = candidates.map { IdentifiedCandidate(a: $0.0, b: $0.1) }
                    ForEach(Array(identified.enumerated()), id: \.element.id) { i, item in
                        candidateRow((item.a, item.b), isLast: i == identified.count - 1)
                    }
                }

                // Create link
                TSectionHead(title: "Manual", count: nil)

                Button {
                    showingLinkPicker = true
                } label: {
                    HStack(spacing: 14) {
                        T3IconImage(systemName: "link.badge.plus")
                            .frame(width: 20, height: 20)
                            .foregroundStyle(T3.ink)
                        Text("Link two devices")
                            .font(T3.inter(15, weight: .medium))
                            .foregroundStyle(T3.ink)
                        Spacer()
                        T3IconImage(systemName: "chevron.right")
                            .frame(width: 12, height: 12)
                            .foregroundStyle(T3.sub)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }
                .accessibilityLabel("Link two devices manually")
                .accessibilityAddTraits(.isButton)

                // Explainer
                Text("Linked devices appear as a single tile on the Devices tab (Merged view). Commands are routed to the best available provider.")
                    .font(T3.inter(12, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 16)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let msg = lastLinkedToast {
                HStack(spacing: 8) {
                    TDot(size: 6, color: T3.accent)
                    Text(msg)
                        .font(T3.inter(13, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(T3.panel)
                .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                .padding(.bottom, 120)
                .padding(.horizontal, 20)
                .transition(.opacity)
                .task(id: msg) {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { lastLinkedToast = nil }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .confirmationDialog("Unlink devices?", isPresented: Binding(
            get: { unlinkCandidate != nil },
            set: { if !$0 { unlinkCandidate = nil } }
        ), titleVisibility: .visible) {
            Button("Unlink", role: .destructive) {
                if let c = unlinkCandidate { linkStore.removeLink(id: c.id) }
                unlinkCandidate = nil
            }
            Button("Cancel", role: .cancel) { unlinkCandidate = nil }
        } message: {
            if let c = unlinkCandidate {
                let primaryName = accessoryName(c.primaryID)
                let secondaryName = accessoryName(c.secondaryID)
                Text("\"\(primaryName)\" and \"\(secondaryName)\" will appear as separate devices again.")
            }
        }
        .confirmationDialog("Clear all links?", isPresented: $confirmClearAll, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { linkStore.removeAllLinks() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes every manual link. You can re-create them from Potential matches or the manual picker.")
        }
        .sheet(isPresented: $showingLinkPicker) {
            T3LinkDevicePickerSheet()
                .environment(registry)
                .environment(linkStore)
        }
    }

    // MARK: - Rows

    private func currentLinkRow(_ link: ManualDeviceLink, isLast: Bool) -> some View {
        let primary   = accessoryName(link.primaryID)
        let secondary = accessoryName(link.secondaryID)

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TDot(size: 5, color: T3.accent)
                    Text(primary)
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.ink)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    TDot(size: 5, color: T3.sub)
                    Text(secondary)
                        .font(T3.inter(13, weight: .regular))
                        .foregroundStyle(T3.sub)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(link.primaryID.provider.displayLabel.uppercased())
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                    Text("→")
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                    Text(link.secondaryID.provider.displayLabel.uppercased())
                        .font(T3.mono(9))
                        .foregroundStyle(T3.sub)
                        .tracking(1)
                }
            }

            Spacer()

            Button {
                unlinkCandidate = link
            } label: {
                T3IconImage(systemName: "xmark")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unlink \(primary) and \(secondary)")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func candidateRow(_ pair: (Accessory, Accessory), isLast: Bool) -> some View {
        let a = pair.0
        let b = pair.1

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(a.name) ↔ \(b.name)")
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                Text("\(a.id.provider.displayLabel) + \(b.id.provider.displayLabel) · \(a.category.displayLabel)")
                    .font(T3.mono(9))
                    .foregroundStyle(T3.sub)
                    .tracking(0.8)
            }

            Spacer()

            Button {
                linkStore.addLink(primary: a.id, secondary: b.id)
                lastLinkedToast = "Linked \(a.name) ↔ \(b.name)"
            } label: {
                Text("LINK")
                    .font(T3.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(T3.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Link \(a.name) with \(b.name)")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    // MARK: - Potential matches

    /// Cross-provider pairs that share the same category and have similar
    /// names (one name contains the other, or both share ≥3 words). Already
    /// manually linked or already auto-merging (same matchKey) are excluded.
    private var potentialMatches: [(Accessory, Accessory)] {
        let all = registry.allAccessories
        let linkedIDs = linkStore.linkedIDs()

        // Group by category
        var byCategory: [Accessory.Category: [Accessory]] = [:]
        for acc in all where !linkedIDs.contains(acc.id) {
            byCategory[acc.category, default: []].append(acc)
        }

        var results: [(Accessory, Accessory)] = []

        for (_, accessories) in byCategory {
            // Only consider cross-provider pairs
            let pairs = accessories.flatMap { a in
                accessories.compactMap { b -> (Accessory, Accessory)? in
                    guard b.id.provider != a.id.provider,
                          a.id < b.id, // avoid (a,b) and (b,a) dupes
                          DeviceMerging.matchKey(for: a) != DeviceMerging.matchKey(for: b)
                    else { return nil }
                    return (a, b)
                }
            }
            for pair in pairs where nameSimilar(pair.0.name, pair.1.name) {
                results.append(pair)
            }
        }

        return results.sorted { $0.0.name < $1.0.name }
    }

    /// True when two names are similar enough to suggest the same device.
    /// Checks: substring, shared significant words, or Levenshtein ≤ 2
    /// on the shorter token.
    private func nameSimilar(_ a: String, _ b: String) -> Bool {
        let an = a.trimmingCharacters(in: .whitespaces).lowercased()
        let bn = b.trimmingCharacters(in: .whitespaces).lowercased()
        guard an != bn else { return false } // already auto-merges

        // HA entity IDs use underscores — normalise
        let anN = an.replacingOccurrences(of: "_", with: " ")
        let bnN = bn.replacingOccurrences(of: "_", with: " ")

        if anN.contains(bnN) || bnN.contains(anN) { return true }

        // Strip domain prefix (e.g. "light." "switch.") from HA entities
        let stripped = { (s: String) -> String in
            let parts = s.split(separator: ".", maxSplits: 1)
            return parts.count == 2 ? String(parts[1]) : s
        }
        let aSt = stripped(anN)
        let bSt = stripped(bnN)
        if aSt.contains(bSt) || bSt.contains(aSt) { return true }

        // Shared meaningful words (≥2 chars, ignore stop words)
        let stop: Set<String> = ["the", "a", "an", "and", "or", "of", "in", "my"]
        let aWords = Set(aSt.components(separatedBy: " ")
                              .filter { $0.count >= 2 && !stop.contains($0) })
        let bWords = Set(bSt.components(separatedBy: " ")
                              .filter { $0.count >= 2 && !stop.contains($0) })
        return aWords.intersection(bWords).count >= 1
    }

    // MARK: - Helpers

    private func accessoryName(_ id: AccessoryID) -> String {
        registry.allAccessories.first(where: { $0.id == id })?.name ?? id.nativeID
    }
}

// MARK: - Two-step link picker

struct T3LinkDevicePickerSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(DeviceLinkStore.self)  private var linkStore
    @Environment(\.dismiss) private var dismiss

    @State private var primaryID: AccessoryID?
    @State private var secondaryID: AccessoryID?
    @State private var step: Int = 1 // 1 = pick primary, 2 = pick secondary

    private var allAccessories: [Accessory] {
        registry.allAccessories.sorted { $0.name < $1.name }
    }

    private var primaryName: String {
        primaryID.flatMap { id in registry.allAccessories.first(where: { $0.id == id })?.name } ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TTitle(
                        title: step == 1 ? "Pick first." : "Pick second.",
                        subtitle: step == 1
                            ? "Choose the primary device (usually HomeKit)"
                            : "Choose the matching device on another provider"
                    )
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 22)

                    if step == 2 {
                        // Show selected primary
                        HStack(spacing: 8) {
                            TDot(size: 6)
                            Text("Primary: \(primaryName)")
                                .font(T3.inter(13, weight: .medium))
                                .foregroundStyle(T3.ink)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 10)
                        TRule()
                    }

                    // Step 2: show every accessory except the primary itself.
                    // Previously filtered by `provider != primary.provider`, but
                    // that hid valid matches whenever both entries actually came
                    // from the same backend (e.g. a HomeKit light also bridged
                    // through HA still carries the user's perception of "two
                    // items"). Keeping it permissive lets the user pick whatever
                    // they see as the duplicate.
                    let eligible = step == 1
                        ? allAccessories
                        : allAccessories.filter { $0.id != primaryID }

                    ForEach(Array(eligible.enumerated()), id: \.element.id) { i, acc in
                        let isSelected = (step == 1 ? primaryID : secondaryID) == acc.id
                        Button {
                            if step == 1 {
                                primaryID = acc.id
                                secondaryID = nil
                                step = 2
                            } else {
                                secondaryID = acc.id
                            }
                        } label: {
                            HStack(spacing: 14) {
                                T3IconImage(systemName: categoryIcon(acc.category))
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(T3.ink)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(acc.name)
                                        .font(T3.inter(15, weight: .medium))
                                        .foregroundStyle(T3.ink)
                                    Text(acc.id.provider.displayLabel.uppercased())
                                        .font(T3.mono(9))
                                        .foregroundStyle(T3.sub)
                                        .tracking(1)
                                }
                                Spacer()
                                if isSelected {
                                    T3IconImage(systemName: "checkmark")
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(T3.accent)
                                }
                            }
                            .padding(.horizontal, T3.screenPadding)
                            .padding(.vertical, 13)
                            .overlay(alignment: .top) { TRule() }
                            .overlay(alignment: .bottom) {
                                if i == eligible.count - 1 { TRule() }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 120)
                }
            }
            .background(T3.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == 2 ? "Back" : "Cancel") {
                        if step == 2 { step = 1; primaryID = nil }
                        else { dismiss() }
                    }
                }
                if step == 2, let pid = primaryID, let sid = secondaryID, pid != sid {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Link") {
                            linkStore.addLink(primary: pid, secondary: sid)
                            dismiss()
                        }
                        .font(T3.inter(15, weight: .medium))
                        .foregroundStyle(T3.accent)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .modifier(T3SheetChromeModifier())
    }

    private func categoryIcon(_ cat: Accessory.Category) -> String {
        switch cat {
        case .light:    "lightbulb"
        case .thermostat: "thermometer.medium"
        case .lock:     "lock.fill"
        case .speaker:  "hifispeaker"
        case .camera:   "video.fill"
        case .fan:      "fan"
        case .blinds:   "blinds.horizontal.closed"
        case .switch, .outlet: "poweroutlet.type.b.fill"
        case .sensor:   "sensor.fill"
        case .television, .appleTV: "tv"
        case .smokeAlarm: "smoke.fill"
        case .other:    "questionmark.app"
        }
    }
}

// MARK: - Identified candidate pair

/// Wrapper giving each candidate pair a stable, ForEach-safe id.
/// The old `id: \.offset` let SwiftUI reuse Button instances against
/// new pair data after the list filtered — scenario A.
private struct IdentifiedCandidate: Identifiable, Hashable {
    let a: Accessory
    let b: Accessory
    var id: String {
        // Both AccessoryIDs namespaced, so joining their native IDs
        // with a separator can't collide with either side alone.
        "\(a.id.provider.rawValue):\(a.id.nativeID)|\(b.id.provider.rawValue):\(b.id.nativeID)"
    }
}

// MARK: - AccessoryID ordered comparison (for stable pair deduplication)

private extension AccessoryID {
    static func < (lhs: AccessoryID, rhs: AccessoryID) -> Bool {
        if lhs.provider.rawValue != rhs.provider.rawValue {
            return lhs.provider.rawValue < rhs.provider.rawValue
        }
        return lhs.nativeID < rhs.nativeID
    }
}

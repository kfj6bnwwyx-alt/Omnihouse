//
//  T3DeviceLinksSection.swift
//  house connect
//
//  "Linked to" section mounted on every device detail view. Shows
//  every OTHER accessory manually linked to this one (across one
//  or more providers) with inline unlink. Also surfaces a "Link
//  another device" action that opens the existing
//  `T3LinkDevicePickerSheet` pre-seeded with this device as the
//  primary side.
//
//  Hidden when the accessory is not part of any manual link AND
//  there are no candidate pairs to create — keeps non-merged
//  device screens clean.
//

import SwiftUI

struct T3DeviceLinksSection: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry
    @Environment(DeviceLinkStore.self) private var linkStore

    @State private var showingLinkPicker = false
    @State private var unlinkCandidate: ManualDeviceLink?

    private var existingLinks: [ManualDeviceLink] {
        linkStore.linksInvolving(accessoryID)
    }

    var body: some View {
        // Show the section whenever this device has links OR when
        // there's at least one other accessory on the house the
        // user could plausibly link it to. The "Link another" row
        // is the discoverability path users asked for.
        let canLink = registry.allAccessories.contains {
            $0.id != accessoryID && !linkStore.areLinked($0.id, accessoryID)
        }

        if !existingLinks.isEmpty || canLink {
            VStack(alignment: .leading, spacing: 0) {
                TSectionHead(
                    title: "Linked devices",
                    count: existingLinks.isEmpty ? nil : String(format: "%02d", existingLinks.count)
                )

                ForEach(Array(existingLinks.enumerated()), id: \.element.id) { i, link in
                    linkRow(
                        link: link,
                        isLast: i == existingLinks.count - 1 && !canLink
                    )
                }

                if canLink {
                    Button {
                        showingLinkPicker = true
                    } label: {
                        HStack(spacing: 14) {
                            T3IconImage(systemName: "link.badge.plus")
                                .frame(width: 18, height: 18)
                                .foregroundStyle(T3.ink)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Link another device")
                                    .font(T3.inter(14, weight: .medium))
                                    .foregroundStyle(T3.ink)
                                Text("MERGE SAME DEVICE ACROSS PROVIDERS")
                                    .font(T3.mono(9))
                                    .tracking(1)
                                    .foregroundStyle(T3.sub)
                            }
                            Spacer()
                            T3IconImage(systemName: "chevron.right")
                                .frame(width: 10, height: 10)
                                .foregroundStyle(T3.sub)
                        }
                        .padding(.horizontal, T3.screenPadding)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.t3Row)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }
                }
            }
            .confirmationDialog(
                "Unlink devices?",
                isPresented: Binding(
                    get: { unlinkCandidate != nil },
                    set: { if !$0 { unlinkCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Unlink", role: .destructive) {
                    if let c = unlinkCandidate { linkStore.removeLink(id: c.id) }
                    unlinkCandidate = nil
                }
                Button("Cancel", role: .cancel) { unlinkCandidate = nil }
            } message: {
                if let c = unlinkCandidate {
                    let primary = accessoryName(c.primaryID)
                    let secondary = accessoryName(c.secondaryID)
                    Text("\"\(primary)\" and \"\(secondary)\" will appear as separate devices again.")
                }
            }
            .sheet(isPresented: $showingLinkPicker) {
                T3LinkDevicePickerSheet(preselectedPrimary: accessoryID)
                    .environment(registry)
                    .environment(linkStore)
            }
        }
    }

    // MARK: - Row

    private func linkRow(link: ManualDeviceLink, isLast: Bool) -> some View {
        // Surface the OTHER side of the link — the user is already
        // looking at this device, they want to know what it's
        // paired with.
        let other = (link.primaryID == accessoryID) ? link.secondaryID : link.primaryID
        let otherName = accessoryName(other)
        let otherRole = (link.primaryID == accessoryID) ? "SECONDARY" : "PRIMARY"

        return HStack(spacing: 14) {
            T3IconImage(systemName: "link")
                .frame(width: 16, height: 16)
                .foregroundStyle(T3.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(otherName)
                    .font(T3.inter(14, weight: .medium))
                    .foregroundStyle(T3.ink)
                    .lineLimit(1)
                Text("\(other.provider.displayLabel.uppercased())  ·  \(otherRole)")
                    .font(T3.mono(9))
                    .tracking(1)
                    .foregroundStyle(T3.sub)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                unlinkCandidate = link
            } label: {
                T3IconImage(systemName: "xmark")
                    .frame(width: 12, height: 12)
                    .foregroundStyle(T3.sub)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unlink \(otherName)")
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func accessoryName(_ id: AccessoryID) -> String {
        registry.allAccessories.first(where: { $0.id == id })?.name ?? id.nativeID
    }
}

//
//  T3DevicesTabView.swift
//  house connect
//
//  T3/Swiss Devices tab — flat filterable list with filter chips.
//

import SwiftUI

struct T3DevicesTabView: View {
    @Environment(ProviderRegistry.self) private var registry

    @State private var filter: String = "All"

    private let filters = ["All", "On", "Lights", "Climate", "Media"]

    private var devices: [Accessory] {
        let all = registry.allAccessories.sorted { $0.name < $1.name }
        switch filter {
        case "On": return all.filter { $0.isOn == true }
        case "Lights": return all.filter { $0.category == .light }
        case "Climate": return all.filter { $0.category == .thermostat }
        case "Media": return all.filter { $0.category == .speaker || $0.category == .television }
        default: return all
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: "Devices.",
                    subtitle: "\(registry.allAccessories.filter { $0.isOn == true }.count) on now · across \(registry.allRooms.count) rooms"
                )

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { f in
                            Button {
                                filter = f
                            } label: {
                                Text(f)
                                    .font(T3.inter(13, weight: .medium))
                                    .foregroundStyle(filter == f ? T3.page : T3.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(filter == f ? T3.ink : .clear)
                                            .overlay(
                                                Capsule().stroke(filter == f ? .clear : T3.rule, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.bottom, 16)
                }

                // Device rows — tap navigates to detail
                ForEach(Array(devices.enumerated()), id: \.element.id) { i, device in
                    NavigationLink(value: device.id) {
                        T3DeviceRow(device: device, index: i, isLast: i == devices.count - 1)
                    }
                    .buttonStyle(.plain)
                }

                // Add device dashed button
                Button { } label: {
                    HStack {
                        T3IconImage(systemName: "plus")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(T3.sub)
                        Text("Add device")
                            .font(T3.inter(14, weight: .medium))
                            .foregroundStyle(T3.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle()
                            .stroke(T3.rule, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, T3.screenPadding)
                .padding(.top, 16)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }
}

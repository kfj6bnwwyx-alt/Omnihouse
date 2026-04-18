//
//  T3AddDeviceSheet.swift
//  house connect
//
//  Presented from T3DevicesTabView's "Add device" button. There is no
//  T3 add-device flow yet — devices are provisioned per-provider, so the
//  actual flow is "pick a provider to add a connection from." This sheet
//  is the honest intermediate: explain where to go and dismiss. The
//  caller handles tab-switching so we don't have to reach across nav
//  stacks.
//

import SwiftUI

struct T3AddDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Invoked when the user taps "Open Connections". Caller should
    /// dismiss any presenting state and route to Settings → Providers.
    var onOpenConnections: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TTitle(
                        title: "Add device.",
                        subtitle: "Devices are added through connections"
                    )

                    // Body copy explaining the flow
                    VStack(alignment: .leading, spacing: 14) {
                        Text("House Connect doesn't provision devices directly. Each device lives in a provider's ecosystem — Home Assistant, SmartThings, Sonos, or Nest.")
                            .font(T3.inter(15, weight: .regular))
                            .foregroundStyle(T3.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Open Connections to add or manage a provider. New devices show up automatically after a provider is connected.")
                            .font(T3.inter(15, weight: .regular))
                            .foregroundStyle(T3.sub)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 18)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }

                    // Primary action
                    Button {
                        dismiss()
                        onOpenConnections()
                    } label: {
                        Text("OPEN CONNECTIONS")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.page)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(T3.ink)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 24)

                    Spacer(minLength: 120)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .background(T3.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationBackground(T3.page)
    }
}

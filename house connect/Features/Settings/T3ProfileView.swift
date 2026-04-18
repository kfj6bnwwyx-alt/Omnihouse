//
//  T3ProfileView.swift
//  house connect
//
//  T3/Swiss profile settings — first name for the Home greeting.
//  Stored in @AppStorage("profile.firstName"). Rest of the profile
//  (email, photo, etc.) lives in Apple ID — we deliberately don't
//  re-collect it here.
//

import SwiftUI

struct T3ProfileView: View {
    @AppStorage("profile.firstName") private var firstName: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Profile.")

                // Name
                TSectionHead(title: "Name", count: firstName.isEmpty ? "" : "01")

                VStack(alignment: .leading, spacing: 10) {
                    TLabel(text: "First name — shown in greetings")

                    HStack(spacing: 0) {
                        TextField("Your name", text: $firstName)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .font(T3.inter(22, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .submitLabel(.done)
                            .onSubmit { focused = false }

                        if !firstName.isEmpty {
                            Button {
                                firstName = ""
                                focused = true
                            } label: {
                                T3IconImage(systemName: "xmark")
                                    .frame(width: 13, height: 13)
                                    .foregroundStyle(T3.sub)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)

                    Rectangle()
                        .fill(focused ? T3.accent : T3.rule)
                        .frame(height: focused ? 1.5 : 1)
                        .animation(.easeOut(duration: 0.18), value: focused)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { TRule() }
                .overlay(alignment: .bottom) { TRule() }

                // Preview
                TSectionHead(title: "Preview", count: "")
                VStack(alignment: .leading, spacing: 4) {
                    Text(previewAttributed)
                        .font(T3.inter(28, weight: .medium))
                        .tracking(-0.8)

                    TLabel(text: "This is how you'll be greeted on Home.")
                        .padding(.top, 4)
                }
                .padding(.horizontal, T3.screenPadding)
                .padding(.vertical, 16)
                .overlay(alignment: .top) { TRule() }

                // Why we ask
                TSectionHead(title: "Why we ask", count: "")
                Text("House Connect stores your name locally on this device only. It's used for personalized greetings and on-screen context — nothing is sent to a server, and no other profile fields (email, photo, address) are collected. Your Apple ID remains the source of truth for those.")
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { TRule() }

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .onAppear { focused = firstName.isEmpty }
    }

    private var previewAttributed: AttributedString {
        let trimmed = firstName.trimmingCharacters(in: .whitespaces)
        var prefix = AttributedString("Good morning")
        prefix.foregroundColor = T3.ink
        var suffix = AttributedString(trimmed.isEmpty ? "." : ", \(trimmed).")
        suffix.foregroundColor = T3.sub
        return prefix + suffix
    }
}

#Preview {
    NavigationStack {
        T3ProfileView()
    }
}

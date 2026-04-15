//
//  NestOAuthView.swift
//  house connect
//
//  Settings sheet for connecting a Google Nest account via OAuth 2.0.
//  Uses ASWebAuthenticationSession to present the Google consent screen,
//  then exchanges the returned authorization code for tokens via
//  NestOAuthManager. Follows the SmartThingsTokenEntryView pattern.
//
//  NOTE: This flow requires a configured Google Device Access project
//  ($5 registration) with OAuth 2.0 credentials. Without them, the
//  NestProvider doesn't register and this view is never presented.
//

import SwiftUI
#if os(iOS)
import AuthenticationServices
#endif

struct NestOAuthView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Custom URL scheme for the OAuth redirect (must match the one
    /// registered in Info.plist and the Google Cloud Console).
    private let redirectURI = "com.houseconnect.app:/oauth2callback"

    private var nestProvider: NestProvider? {
        registry.provider(for: .nest) as? NestProvider
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.green)

                Text("Connect Google Nest")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.color.title)

                Text("Sign in with your Google account to access Nest thermostats, cameras, and doorbells.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.color.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .padding(.horizontal)
                        .accessibilityLabel("Error: \(errorMessage)")
                }

                Button {
                    startOAuth()
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isLoading ? "Connecting…" : "Sign in with Google")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Theme.color.primary))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .accessibilityLabel(isLoading ? "Connecting to Google" : "Sign in with Google")
                .accessibilityHint("Opens Google sign-in to connect your Nest account")

                Text("Requires a Google Device Access project.\nLearn more at developers.google.com/nest")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.color.muted)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - OAuth Flow

    private func startOAuth() {
        #if os(iOS)
        guard let provider = nestProvider else {
            errorMessage = "Nest provider not configured"
            return
        }

        guard !provider.projectID.isEmpty else {
            errorMessage = "Google Device Access project not configured"
            return
        }

        isLoading = true
        errorMessage = nil

        // In a real implementation, this would use ASWebAuthenticationSession
        // to open the Google consent URL and capture the redirect callback.
        // Since we can't test without actual OAuth credentials, we show the
        // flow structure but leave the actual session as a TODO.
        //
        // TODO: Wire ASWebAuthenticationSession when credentials are available:
        //   1. let url = oauthManager.buildAuthorizationURL(redirectURI: redirectURI)
        //   2. ASWebAuthenticationSession(url: url, callbackURLScheme: "com.houseconnect.app")
        //   3. Extract `code` from callback URL query params
        //   4. await oauthManager.exchangeCode(code, redirectURI: redirectURI)
        //   5. await provider.refresh()
        //   6. dismiss()

        Task {
            // Placeholder — trigger a refresh to test the flow
            await provider.refresh()
            isLoading = false
            if provider.authorizationState == .authorized {
                dismiss()
            } else {
                errorMessage = provider.lastError ?? "Connection failed — check your credentials"
            }
        }
        #else
        errorMessage = "OAuth sign-in requires iOS"
        #endif
    }
}

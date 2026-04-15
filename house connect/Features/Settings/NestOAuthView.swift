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
    #if os(iOS)
    @State private var sessionCoordinator = WebAuthSessionCoordinator()
    #endif

    /// Custom URL scheme for the OAuth redirect. The scheme portion
    /// (`houseconnect`) must match:
    ///   1. The URL Type registered in the project's Info settings
    ///   2. The Authorized redirect URI configured in Google Cloud Console
    /// Google requires an HTTPS redirect for Web-app OAuth clients OR a
    /// custom URL scheme for installed-app clients — we use the custom
    /// scheme approach since Apple's ASWebAuthenticationSession handles
    /// the callback natively without needing a web server.
    private let redirectURI = "houseconnect://oauth2callback"

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

        guard let authURL = provider.buildAuthorizationURL(redirectURI: redirectURI) else {
            errorMessage = "Could not construct Google sign-in URL"
            return
        }

        isLoading = true
        errorMessage = nil

        // Fire ASWebAuthenticationSession. The OS shows Google's consent
        // page in a SFSafariViewController-style sheet, and when Google
        // redirects to our custom scheme the completion handler fires
        // with the callback URL. We extract `?code=...` from the query,
        // exchange it for tokens, then refresh the provider.
        sessionCoordinator.start(
            authURL: authURL,
            callbackScheme: "houseconnect"
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let callbackURL):
                    await handleCallback(callbackURL, provider: provider)
                case .failure(let error):
                    isLoading = false
                    // User cancel is the most common path — show a
                    // friendlier message than the raw error description.
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        errorMessage = nil
                    } else {
                        errorMessage = "Sign-in failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        #else
        errorMessage = "OAuth sign-in requires iOS"
        #endif
    }

    #if os(iOS)
    /// Handles the redirect URL from Google, extracts the authorization
    /// code, and exchanges it for tokens.
    @MainActor
    private func handleCallback(_ url: URL, provider: NestProvider) async {
        defer { isLoading = false }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            // Check for error param (user denied consent, invalid scope, etc.)
            let errorParam = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "error" })?.value
            errorMessage = "Sign-in failed: \(errorParam ?? "no authorization code in response")"
            return
        }

        do {
            try await provider.exchangeOAuthCode(code, redirectURI: redirectURI)
            await provider.refresh()

            if provider.authorizationState == .authorized {
                dismiss()
            } else {
                errorMessage = provider.lastError ?? "Token exchange succeeded but refresh failed"
            }
        } catch {
            errorMessage = "Token exchange failed: \(error.localizedDescription)"
        }
    }
    #endif
}

#if os(iOS)

// MARK: - ASWebAuthenticationSession wrapper

/// Bridges ASWebAuthenticationSession's completion-handler API into a
/// value-type-friendly shape the SwiftUI view can own. Keeps a reference
/// to the live session so it isn't deallocated mid-flow, and supplies
/// the presentation anchor via the delegate protocol.
@MainActor
@Observable
final class WebAuthSessionCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    @ObservationIgnored private var session: ASWebAuthenticationSession?

    func start(
        authURL: URL,
        callbackScheme: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { callbackURL, error in
            if let error {
                completion(.failure(error))
            } else if let callbackURL {
                completion(.success(callbackURL))
            } else {
                completion(.failure(NSError(domain: "NestOAuth", code: -1)))
            }
        }
        session.presentationContextProvider = self
        // prefersEphemeralWebBrowserSession keeps any prior Google cookies
        // out of the flow — forces a fresh consent prompt every time.
        // Set to false so returning users can use their existing session.
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        session.start()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // ASPresentationAnchor is UIWindow on iOS. Use the key window of
        // the connected scene. Fall back to a fresh UIWindow if somehow
        // nothing is connected (shouldn't happen in normal app flow).
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
                ?? UIWindow()
        }
    }
}

#endif

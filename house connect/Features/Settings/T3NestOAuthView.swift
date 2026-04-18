//
//  T3NestOAuthView.swift
//  house connect
//
//  Google SDM OAuth flow in T3/Swiss styling. Pushed from
//  T3ProviderDetailView; all ASWebAuthenticationSession + keychain
//  semantics preserved verbatim from the legacy NestOAuthView.
//

import SwiftUI
#if os(iOS)
import AuthenticationServices

struct T3NestOAuthView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var state: AuthState = .idle
    @State private var error: String?
    @State private var sessionCoordinator = T3WebAuthSessionCoordinator()

    enum AuthState: Equatable {
        case idle, authorizing, authorized
    }

    /// Custom URL scheme for the OAuth redirect. The scheme portion
    /// (`houseconnect`) must match:
    ///   1. The URL Type registered in the project's Info settings
    ///   2. The Authorized redirect URI configured in Google Cloud Console
    private let redirectURI = "houseconnect://oauth2callback"

    private var nestProvider: NestProvider? {
        registry.provider(for: .nest) as? NestProvider
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Nest.", subtitle: "Google Smart Device Management")
                    .t3ScreenTopPad()

                TSectionHead(title: "Connection", count: "")
                connectionBlock

                TSectionHead(title: "What we access", count: "04")
                capabilityRow(icon: "thermometer.medium", title: "Thermostats", sub: "READ + WRITE TEMPERATURE")
                capabilityRow(icon: "exclamationmark.triangle", title: "Protect smoke alarms", sub: "READ + CRITICAL ALERTS")
                capabilityRow(icon: "video", title: "Cameras", sub: "READ ONLY · STREAM TOKENS")
                capabilityRow(icon: "lock", title: "Locks", sub: "READ + WRITE STATE", isLast: true)

                if let error {
                    errorBlock(error)
                }

                actionButton

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var connectionBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            TDot(size: 8, color: statusColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: statusSub)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    private var statusColor: Color {
        switch state {
        case .idle: return T3.sub
        case .authorizing: return T3.accent
        case .authorized: return T3.ok
        }
    }

    private var statusTitle: String {
        switch state {
        case .idle: return "Not connected"
        case .authorizing: return "Waiting for Google…"
        case .authorized: return "Connected"
        }
    }

    private var statusSub: String {
        switch state {
        case .idle: return "AUTHORIZE TO CONTINUE"
        case .authorizing: return "IN-APP BROWSER"
        case .authorized: return "GOOGLE SDM · OAUTH"
        }
    }

    private func capabilityRow(icon: String, title: String, sub: String, isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: sub)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func errorBlock(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(T3.danger)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                TLabel(text: "AUTHORIZATION FAILED",
                       color: T3.danger)
                Text(message)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.ink)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
    }

    private var actionButton: some View {
        Button {
            startOAuth()
        } label: {
            HStack(spacing: 10) {
                if state == .authorizing {
                    ProgressView().tint(T3.page).scaleEffect(0.8)
                }
                Text(state == .authorized ? "DISCONNECT" : "AUTHORIZE WITH GOOGLE")
                    .font(T3.mono(12))
                    .tracking(2)
                    .foregroundStyle(T3.page)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(T3.ink)
        }
        .buttonStyle(.plain)
        .disabled(state == .authorizing)
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 24)
    }

    // MARK: - OAuth Flow (ported verbatim from NestOAuthView)

    private func startOAuth() {
        guard let provider = nestProvider else {
            error = "Nest provider not configured"
            return
        }

        guard !provider.projectID.isEmpty else {
            error = "Google Device Access project not configured"
            return
        }

        guard let authURL = provider.buildAuthorizationURL(redirectURI: redirectURI) else {
            error = "Could not construct Google sign-in URL"
            return
        }

        state = .authorizing
        error = nil

        sessionCoordinator.start(
            authURL: authURL,
            callbackScheme: "houseconnect"
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let callbackURL):
                    await handleCallback(callbackURL, provider: provider)
                case .failure(let err):
                    state = .idle
                    if (err as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        error = nil
                    } else {
                        error = "Sign-in failed: \(err.localizedDescription)"
                    }
                }
            }
        }
    }

    @MainActor
    private func handleCallback(_ url: URL, provider: NestProvider) async {
        defer {
            if state == .authorizing { state = .idle }
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            let errorParam = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "error" })?.value
            error = "Sign-in failed: \(errorParam ?? "no authorization code in response")"
            return
        }

        do {
            try await provider.exchangeOAuthCode(code, redirectURI: redirectURI)
            await provider.refresh()

            if provider.authorizationState == .authorized {
                state = .authorized
                dismiss()
            } else {
                error = provider.lastError ?? "Token exchange succeeded but refresh failed"
            }
        } catch let exchangeError {
            error = "Token exchange failed: \(exchangeError.localizedDescription)"
        }
    }
}

// MARK: - ASWebAuthenticationSession wrapper

/// Bridges ASWebAuthenticationSession's completion-handler API into a
/// value-type-friendly shape the SwiftUI view can own. Keeps a reference
/// to the live session so it isn't deallocated mid-flow, and supplies
/// the presentation anchor via the delegate protocol.
@MainActor
@Observable
final class T3WebAuthSessionCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    @ObservationIgnored private var session: ASWebAuthenticationSession?

    func start(
        authURL: URL,
        callbackScheme: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Ensure we have a connected UIWindowScene before starting. The
        // presentation-anchor delegate method can't return nil, so if
        // we're in a scene-less state (edge cases like background/multi-
        // scene teardown) we fail gracefully instead of crashing.
        let hasScene = UIApplication.shared.connectedScenes
            .contains { $0 is UIWindowScene }
        guard hasScene else {
            completion(.failure(NSError(
                domain: "NestOAuth",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Could not open sign-in window. Please try again."]
            )))
            return
        }

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
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return keyWindow
            }
            // Fallback: the OAuth flow requires an active scene. `start()`
            // pre-checks for a connected UIWindowScene so this branch
            // should be unreachable — but the delegate return is
            // non-optional, so if we somehow get here, hand back a bare
            // UIWindow. ASWebAuthenticationSession will fail to present
            // and surface a normal error through its completion handler
            // rather than crashing the app.
            guard let scene = scenes.first else {
                return UIWindow()
            }
            return UIWindow(windowScene: scene)
        }
    }
}

#endif

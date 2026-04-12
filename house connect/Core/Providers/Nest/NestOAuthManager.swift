//
//  NestOAuthManager.swift
//  house connect
//
//  Manages Google OAuth 2.0 tokens for the Nest SDM API. Handles:
//    - Building the authorization URL for the consent screen
//    - Exchanging an authorization code for access + refresh tokens
//    - Refreshing an expired access token
//    - Persisting tokens in KeychainTokenStore
//
//  This is a non-UI class — the actual ASWebAuthenticationSession lives
//  in NestOAuthView (Settings). This class just handles the token math
//  and persistence.
//
//  NOTE: Requires a $5 Google Device Access Console registration and a
//  configured OAuth 2.0 client. The app falls back to DemoNestProvider
//  when credentials are absent.
//

import Foundation

@MainActor
final class NestOAuthManager {

    struct Configuration {
        let projectID: String
        let clientID: String
        let clientSecret: String
    }

    private let config: Configuration
    private let tokenStore: KeychainTokenStore
    private let session: URLSession

    init(config: Configuration, tokenStore: KeychainTokenStore, session: URLSession = .shared) {
        self.config = config
        self.tokenStore = tokenStore
        self.session = session
    }

    /// Whether we have stored tokens (may be expired but refreshable).
    var hasTokens: Bool {
        tokenStore.hasToken(for: .nestAccessToken)
    }

    /// Current access token, or nil.
    var accessToken: String? {
        tokenStore.token(for: .nestAccessToken)
    }

    /// The Google Device Access project ID.
    var projectID: String { config.projectID }

    // MARK: - Authorization URL

    /// Builds the Google OAuth consent URL. The caller opens this in
    /// ASWebAuthenticationSession or a browser. After consent, Google
    /// redirects back with a `code` query parameter.
    func buildAuthorizationURL(redirectURI: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "nestservices.google.com"
        components.path = "/partnerconnections/\(config.projectID)/auth"
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/sdm.service"),
        ]
        return components.url
    }

    // MARK: - Code Exchange

    /// Exchanges an authorization code for access + refresh tokens.
    /// Called once after the user completes the OAuth consent flow.
    func exchangeCode(_ code: String, redirectURI: String) async throws {
        let params: [String: String] = [
            "client_id": config.clientID,
            "client_secret": config.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]
        let response = try await postTokenRequest(params: params)
        try persistTokens(response)
    }

    // MARK: - Token Refresh

    /// Refreshes the access token using the stored refresh token.
    /// Returns the new access token. Throws on failure (network,
    /// invalid refresh token, etc.).
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = tokenStore.token(for: .nestRefreshToken) else {
            throw NestSDMError.missingToken
        }
        let params: [String: String] = [
            "client_id": config.clientID,
            "client_secret": config.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        let response = try await postTokenRequest(params: params)
        try persistTokens(response)
        return response.accessToken
    }

    // MARK: - Clear

    /// Removes all Nest tokens from the keychain. Called on explicit
    /// disconnect so re-auth requires a fresh consent flow.
    func clearTokens() {
        try? tokenStore.delete(.nestAccessToken)
        try? tokenStore.delete(.nestRefreshToken)
    }

    // MARK: - Private

    private func postTokenRequest(
        params: [String: String]
    ) async throws -> NestSDMDTO.TokenResponse {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw NestSDMError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        request.httpBody = Data(body.utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NestSDMError.transport(error)
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NestSDMError.http(status: status, message: "Token exchange failed")
        }

        do {
            return try JSONDecoder().decode(NestSDMDTO.TokenResponse.self, from: data)
        } catch {
            throw NestSDMError.decoding(error)
        }
    }

    private func persistTokens(_ response: NestSDMDTO.TokenResponse) throws {
        try tokenStore.set(response.accessToken, for: .nestAccessToken)
        // Refresh token may rotate — persist the new one if provided.
        if let refreshToken = response.refreshToken {
            try tokenStore.set(refreshToken, for: .nestRefreshToken)
        }
    }
}

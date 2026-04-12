//
//  NestSDMAPIClient.swift
//  house connect
//
//  Thin async wrapper over the Google Smart Device Management REST API.
//  Follows the SmartThingsAPIClient pattern: injected token provider,
//  typed error enum, URLSession-based transport.
//
//  Key difference from SmartThings: automatic token refresh on 401.
//  Google OAuth access tokens expire hourly; rather than surfacing
//  "token expired" to the user, we transparently refresh once and
//  retry. If the retry also 401s, we throw `.tokenExpired` so the
//  provider can flip to `.denied` auth state.
//
//  API base: https://smartdevicemanagement.googleapis.com/v1
//

import Foundation

enum NestSDMError: Error, LocalizedError {
    case missingToken
    case badURL
    case tokenExpired
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int, message: String?)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Nest isn't connected yet. Sign in with Google in Settings."
        case .badURL:
            return "Internal error: could not build SDM URL."
        case .tokenExpired:
            return "Your Google Nest session expired. Please sign in again in Settings → Connections."
        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                let rounded = Int(retryAfter.rounded(.up))
                return "Google API is busy — try again in \(rounded) second\(rounded == 1 ? "" : "s")."
            }
            return "Google API is busy — please try again in a moment."
        case .http(let status, let message):
            if let message { return "Nest error \(status): \(message)" }
            return "Nest error \(status)."
        case .transport(let e):
            return "Network error: \(e.localizedDescription)"
        case .decoding(let e):
            return "Couldn't parse Nest response: \(e.localizedDescription)"
        }
    }
}

/// Returns the current Nest access token, or nil if not stored.
typealias NestTokenProvider = @MainActor () -> String?

/// Refreshes the access token and returns the new one. Throws on failure.
typealias NestTokenRefresher = @MainActor () async throws -> String

@MainActor
final class NestSDMAPIClient {
    private let baseURL = URL(string: "https://smartdevicemanagement.googleapis.com/v1")!
    private let session: URLSession
    private let tokenProvider: NestTokenProvider
    private let tokenRefresher: NestTokenRefresher?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Serial refresh lock — prevents multiple concurrent 401 responses
    /// from each independently refreshing the token. Only one refresh
    /// runs at a time; others await its result.
    private var activeRefreshTask: Task<String, Error>?

    init(
        tokenProvider: @escaping NestTokenProvider,
        tokenRefresher: NestTokenRefresher? = nil,
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
        self.session = session
    }

    // MARK: - Public endpoints

    func fetchDevices(projectID: String) async throws -> [NestSDMDTO.Device] {
        let response: NestSDMDTO.DevicesResponse = try await get(
            "/enterprises/\(projectID)/devices"
        )
        return response.devices
    }

    func fetchDevice(projectID: String, deviceID: String) async throws -> NestSDMDTO.Device {
        try await get("/enterprises/\(projectID)/devices/\(deviceID)")
    }

    func fetchStructures(projectID: String) async throws -> [NestSDMDTO.Structure] {
        let response: NestSDMDTO.StructuresResponse = try await get(
            "/enterprises/\(projectID)/structures"
        )
        return response.structures
    }

    func executeCommand(
        projectID: String,
        deviceID: String,
        command: String,
        params: [String: NestSDMDTO.AnyCodableValue]? = nil
    ) async throws {
        let body = NestSDMDTO.CommandRequest(command: command, params: params)
        _ = try await post(
            "/enterprises/\(projectID)/devices/\(deviceID):executeCommand",
            body: body,
            expect: EmptyDecodable.self
        )
    }

    // MARK: - Core request machinery

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", body: Optional<EmptyDecodable>.none)
        return try await sendWithRefresh(request)
    }

    private func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        expect: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", body: body)
        return try await sendWithRefresh(request)
    }

    private func makeRequest<B: Encodable>(
        path: String,
        method: String,
        body: B?
    ) throws -> URLRequest {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw NestSDMError.missingToken
        }
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw NestSDMError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    /// Sends a request; on 401, tries refreshing the token once and retries.
    /// Uses a serial lock so concurrent 401s don't each independently refresh.
    private func sendWithRefresh<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            return try await send(request)
        } catch NestSDMError.http(let status, _) where status == 401 {
            guard let refresher = tokenRefresher else {
                throw NestSDMError.tokenExpired
            }

            // Serial refresh: if a refresh is already in flight, piggyback
            // on it instead of firing a second one.
            let newToken: String
            if let existing = activeRefreshTask {
                do {
                    newToken = try await existing.value
                } catch {
                    throw NestSDMError.tokenExpired
                }
            } else {
                let task = Task { try await refresher() }
                activeRefreshTask = task
                do {
                    newToken = try await task.value
                    activeRefreshTask = nil
                } catch {
                    activeRefreshTask = nil
                    throw NestSDMError.tokenExpired
                }
            }

            // Rebuild the request with the fresh token.
            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await send(retryRequest)
        }
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NestSDMError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NestSDMError.http(status: -1, message: "No HTTP response")
        }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0.trimmingCharacters(in: .whitespaces)) }
            throw NestSDMError.rateLimited(retryAfter: retryAfter)
        }

        guard (200..<300).contains(http.statusCode) else {
            // Google SDM errors come as { "error": { "code": 401, "message": "...", "status": "..." } }
            let message = (try? decoder.decode(GoogleErrorEnvelope.self, from: data))?.error?.message
            throw NestSDMError.http(status: http.statusCode, message: message)
        }

        if T.self == EmptyDecodable.self {
            return EmptyDecodable() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NestSDMError.decoding(error)
        }
    }
}

// MARK: - Private helpers

private struct EmptyDecodable: Codable {}

private struct GoogleErrorEnvelope: Decodable {
    let error: GoogleError?
    struct GoogleError: Decodable {
        let code: Int?
        let message: String?
        let status: String?
    }
}

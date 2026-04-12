//
//  SmartThingsAPIClient.swift
//  house connect
//
//  Thin async wrapper over the SmartThings REST API. Knows how to:
//    - attach the bearer token to every request
//    - decode JSON responses into our DTOs
//    - turn HTTP errors into typed `SmartThingsError` cases
//
//  It does NOT know about our unified domain model. That translation lives
//  in SmartThingsCapabilityMapper / SmartThingsProvider. Keeping the client
//  dumb makes it easy to unit-test with URLProtocol stubs later.
//
//  Auth: Personal Access Token (PAT) for now. When we graduate to OAuth,
//  replace `tokenProvider` with something that refreshes tokens and this
//  client won't have to change.
//

import Foundation

enum SmartThingsError: Error, LocalizedError {
    case missingToken
    case badURL
    /// HTTP 429 — SmartThings rate limiter has kicked in. Callers
    /// should surface this specifically so the UI can render a
    /// friendly "slow down" message instead of leaking raw HTTP
    /// codes. `retryAfter` is populated from the `Retry-After`
    /// response header when present (seconds), else nil — the
    /// API doesn't always include it.
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int, message: String?)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "SmartThings isn't connected yet. Add a personal access token in Settings."
        case .badURL:
            return "Internal error: could not build SmartThings URL."
        case .rateLimited(let retryAfter):
            // Deliberately human-friendly, no HTTP code. The UI
            // already has inline error banners for this kind of
            // message; a user should never see "429" in the app.
            if let retryAfter, retryAfter > 0 {
                let rounded = Int(retryAfter.rounded(.up))
                return "SmartThings is busy — try again in \(rounded) second\(rounded == 1 ? "" : "s")."
            }
            return "SmartThings is busy right now — please try again in a moment."
        case .http(let status, let message):
            if let message { return "SmartThings error \(status): \(message)" }
            return "SmartThings error \(status)."
        case .transport(let e):
            return "Network error: \(e.localizedDescription)"
        case .decoding(let e):
            return "Couldn't parse SmartThings response: \(e.localizedDescription)"
        }
    }
}

/// A function that returns the current PAT, or `nil` if none is stored.
/// Injected so the client never touches Keychain directly — easier to test.
typealias SmartThingsTokenProvider = @MainActor () -> String?

@MainActor
final class SmartThingsAPIClient {
    private let baseURL = URL(string: "https://api.smartthings.com")!
    private let session: URLSession
    private let tokenProvider: SmartThingsTokenProvider
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(tokenProvider: @escaping SmartThingsTokenProvider,
         session: URLSession = .shared) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Public endpoints

    func fetchLocations() async throws -> [SmartThingsDTO.Location] {
        let response: SmartThingsDTO.LocationsResponse = try await get("/v1/locations")
        return response.items
    }

    func fetchRooms(locationId: String) async throws -> [SmartThingsDTO.Room] {
        let response: SmartThingsDTO.RoomsResponse = try await get("/v1/locations/\(locationId)/rooms")
        return response.items
    }

    func fetchDevices() async throws -> [SmartThingsDTO.Device] {
        let response: SmartThingsDTO.DevicesResponse = try await get("/v1/devices")
        return response.items
    }

    func fetchDeviceStatus(deviceId: String) async throws -> SmartThingsDTO.DeviceStatus {
        try await get("/v1/devices/\(deviceId)/status")
    }

    /// Sends a command (or batch of commands) to a device.
    func executeCommands(
        deviceId: String,
        commands: [SmartThingsDTO.Command]
    ) async throws {
        let envelope = SmartThingsDTO.CommandEnvelope(commands: commands)
        _ = try await post(
            "/v1/devices/\(deviceId)/commands",
            body: envelope,
            expect: EmptyDecodable.self
        )
    }

    // MARK: - Device mutations

    /// Renames a device (changes its user-facing `label`).
    func renameDevice(deviceId: String, newLabel: String) async throws {
        _ = try await put(
            "/v1/devices/\(deviceId)",
            body: SmartThingsDTO.DeviceLabelUpdate(label: newLabel),
            expect: EmptyDecodable.self
        )
    }

    /// Moves a device into a room (or out of any room if `roomId` is nil).
    func assignDevice(
        deviceId: String,
        toRoomId roomId: String?,
        inLocation locationId: String
    ) async throws {
        _ = try await put(
            "/v1/devices/\(deviceId)",
            body: SmartThingsDTO.DeviceRoomUpdate(roomId: roomId, locationId: locationId),
            expect: EmptyDecodable.self
        )
    }

    /// Deletes a device from the SmartThings account. Irreversible —
    /// the device must be re-paired to come back.
    func deleteDevice(deviceId: String) async throws {
        let request = try makeRequest(
            path: "/v1/devices/\(deviceId)",
            method: "DELETE",
            body: Optional<EmptyDecodable>.none
        )
        // DELETE returns 200 with an empty body on success. We decode
        // into EmptyDecodable which accepts anything, including empty.
        let _: EmptyDecodable = try await send(request)
    }

    // MARK: - Room mutations

    func createRoom(
        name: String,
        inLocation locationId: String
    ) async throws -> SmartThingsDTO.Room {
        try await post(
            "/v1/locations/\(locationId)/rooms",
            body: SmartThingsDTO.CreateRoomRequest(name: name),
            expect: SmartThingsDTO.Room.self
        )
    }

    func renameRoom(
        roomId: String,
        inLocation locationId: String,
        newName: String
    ) async throws {
        _ = try await put(
            "/v1/locations/\(locationId)/rooms/\(roomId)",
            body: SmartThingsDTO.UpdateRoomRequest(name: newName),
            expect: EmptyDecodable.self
        )
    }

    func deleteRoom(
        roomId: String,
        inLocation locationId: String
    ) async throws {
        let request = try makeRequest(
            path: "/v1/locations/\(locationId)/rooms/\(roomId)",
            method: "DELETE",
            body: Optional<EmptyDecodable>.none
        )
        let _: EmptyDecodable = try await send(request)
    }

    // MARK: - Core request machinery

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", body: Optional<EmptyDecodable>.none)
        return try await send(request)
    }

    private func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        expect: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", body: body)
        return try await send(request)
    }

    private func put<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        expect: T.Type
    ) async throws -> T {
        let request = try makeRequest(path: path, method: "PUT", body: body)
        return try await send(request)
    }

    private func makeRequest<B: Encodable>(
        path: String,
        method: String,
        body: B?
    ) throws -> URLRequest {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw SmartThingsError.missingToken
        }
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw SmartThingsError.badURL
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

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SmartThingsError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SmartThingsError.http(status: -1, message: "No HTTP response")
        }

        // Rate limit is common enough to warrant its own branch
        // before the generic non-2xx handler. SmartThings caps
        // writes at ~50 req/min per token plus per-device bursts,
        // so a rapid tap sequence (toggle + brightness drag) can
        // blow through that in under a second. We translate to
        // the typed `.rateLimited` case so the provider layer
        // can debounce + retry with real semantics instead of
        // sniffing string contents of a `.http` message.
        if http.statusCode == 429 {
            let retryAfter = Self.parseRetryAfter(from: http)
            throw SmartThingsError.rateLimited(retryAfter: retryAfter)
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(SmartThingsDTO.ErrorEnvelope.self, from: data))?
                .error?.message
            throw SmartThingsError.http(status: http.statusCode, message: message)
        }

        // An empty 2xx is common for commands — return a dummy.
        if T.self == EmptyDecodable.self {
            // Force-cast is safe: T is literally EmptyDecodable here.
            return EmptyDecodable() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SmartThingsError.decoding(error)
        }
    }

    /// Pulls `Retry-After` off a 429 response. Per RFC 7231 this can
    /// be either an integer number of seconds or an HTTP-date; the
    /// SmartThings API only ever sends the integer form in practice,
    /// so we handle that and ignore the date form (returning nil
    /// falls back to the generic "try again in a moment" message).
    private static func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        let header = response.value(forHTTPHeaderField: "Retry-After")
            ?? response.value(forHTTPHeaderField: "retry-after")
        guard let header, let seconds = TimeInterval(header.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return seconds
    }
}

/// Placeholder type for endpoints that don't return a body we care about.
private struct EmptyDecodable: Codable {}

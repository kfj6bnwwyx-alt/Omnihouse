//
//  HomeAssistantRESTClient.swift
//  house connect
//
//  Thin REST client for Home Assistant endpoints that don't go through
//  WebSocket: camera proxy snapshots, config check, and fallback state
//  fetching when the WebSocket is down.
//
//  The WebSocket client handles the primary data flow (states, events,
//  service calls). This client covers the edges.
//

import Foundation

final class HomeAssistantRESTClient: Sendable {
    let baseURL: URL
    private let token: String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - Health / Config

    /// Quick connectivity check. Returns true if the server responds.
    func checkConnection() async -> Bool {
        guard let (_, response) = try? await request(path: "/api/") else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    /// Fetch HA config (location name, version, unit system, etc.).
    func getConfig() async throws -> HAConfig {
        try await get("/api/config")
    }

    // MARK: - States (fallback — prefer WebSocket)

    /// Fetch all entity states. Use when WebSocket isn't connected.
    func getAllStates() async throws -> [HAEntityState] {
        try await get("/api/states")
    }

    /// Fetch a single entity's state.
    func getState(entityID: String) async throws -> HAEntityState {
        try await get("/api/states/\(entityID)")
    }

    // MARK: - Service Calls (fallback — prefer WebSocket)

    /// Call a service via REST. Returns the changed states.
    @discardableResult
    func callService(
        domain: String,
        service: String,
        data: [String: Any] = [:],
        entityID: String? = nil
    ) async throws -> [HAEntityState] {
        var body = data
        if let entityID {
            body["entity_id"] = entityID
        }
        return try await post("/api/services/\(domain)/\(service)", body: body)
    }

    // MARK: - Camera

    /// Get the camera proxy snapshot URL. The caller feeds this into
    /// AsyncImage or URLSession directly — the URL includes the auth
    /// token as a query parameter so no extra headers are needed.
    func cameraProxyURL(entityID: String) -> URL {
        // Drop the leading "/" — appendingPathComponent would double-encode it
        // producing "http://ha.local//api/camera_proxy/..." which 404s.
        baseURL.appendingPathComponent("api/camera_proxy/\(entityID)")
    }

    /// Fetch a camera snapshot as raw image data.
    func cameraSnapshot(entityID: String) async throws -> Data {
        let (data, response) = try await request(path: "/api/camera_proxy/\(entityID)")
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw HARESTError.badResponse
        }
        return data
    }

    // MARK: - Scenes & Automations

    /// Activate a scene by entity_id.
    func activateScene(entityID: String) async throws {
        try await callService(domain: "scene", service: "turn_on", entityID: entityID)
    }

    /// Trigger an automation by entity_id.
    func triggerAutomation(entityID: String) async throws {
        try await callService(domain: "automation", service: "trigger", entityID: entityID)
    }

    // MARK: - Internals

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await request(path: path)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw HARESTError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HARESTError.badResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func request(path: String) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await URLSession.shared.data(for: req)
    }
}

enum HARESTError: Error, LocalizedError {
    case badResponse
    case notConnected

    var errorDescription: String? {
        switch self {
        case .badResponse: "Home Assistant returned an unexpected response."
        case .notConnected: "Not connected to Home Assistant."
        }
    }
}

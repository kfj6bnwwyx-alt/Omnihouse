//
//  SmartThingsSSEClient.swift
//  house connect
//
//  Server-Sent Events (SSE) client for real-time SmartThings device
//  state updates. Replaces polling with push: the SSE endpoint streams
//  device events as they happen, so tile states update in <1s instead
//  of waiting for the next manual refresh.
//
//  Endpoint: GET https://api.smartthings.com/v1/sse/devices
//  Auth: Bearer PAT (same as REST API)
//  Content-Type: text/event-stream (SSE spec)
//
//  Architecture:
//    - Uses URLSession.bytes(for:) (iOS 15+) to consume the stream
//    - Parses SSE lines into typed SmartThingsDeviceEvent structs
//    - Reconnects with exponential backoff on network errors
//    - Stops on 401/403 (token revoked) and notifies the provider
//
//  Threading: @MainActor — matches SmartThingsProvider so event
//  callbacks can mutate accessories directly.
//

import Foundation

@MainActor
final class SmartThingsSSEClient {

    enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    private(set) var state: ConnectionState = .disconnected

    private let tokenProvider: SmartThingsTokenProvider
    private let onEvent: (SmartThingsDeviceEvent) -> Void
    private let onAuthFailure: () -> Void
    private let session: URLSession

    private var streamTask: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetryDelay: TimeInterval = 60

    static let sseURL = URL(string: "https://api.smartthings.com/v1/sse/devices")!

    init(
        tokenProvider: @escaping SmartThingsTokenProvider,
        onEvent: @escaping (SmartThingsDeviceEvent) -> Void,
        onAuthFailure: @escaping () -> Void,
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.onEvent = onEvent
        self.onAuthFailure = onAuthFailure
        self.session = session
    }

    // MARK: - Lifecycle

    /// Opens the SSE connection. Idempotent — no-op if already connected.
    func connect() {
        guard streamTask == nil else { return }
        state = .connecting
        streamTask = Task { await runStream() }
    }

    /// Closes the SSE connection. Safe to call when already disconnected.
    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        state = .disconnected
        retryCount = 0
    }

    // MARK: - Stream loop

    private func runStream() async {
        while !Task.isCancelled {
            guard let token = tokenProvider(), !token.isEmpty else {
                state = .failed("No token")
                onAuthFailure()
                return
            }

            var request = URLRequest(url: Self.sseURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            // Keep-alive: SSE connections are long-lived
            request.timeoutInterval = 300

            do {
                let (bytes, response) = try await session.bytes(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw SSEError.noResponse
                }

                if http.statusCode == 401 || http.statusCode == 403 {
                    state = .failed("Auth failed (\(http.statusCode))")
                    onAuthFailure()
                    return // Don't retry on auth failure
                }

                if http.statusCode == 429 {
                    let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(TimeInterval.init) ?? 30
                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    continue
                }

                guard (200..<300).contains(http.statusCode) else {
                    throw SSEError.httpError(http.statusCode)
                }

                // Connected successfully — reset retry count
                state = .connected
                retryCount = 0

                // Parse SSE lines
                try await parseSSEStream(bytes)

            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                // Reconnect with exponential backoff
                state = .failed(error.localizedDescription)
                let delay = min(pow(2.0, Double(retryCount)), maxRetryDelay)
                retryCount += 1
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: - SSE parsing

    /// Parses a Server-Sent Events stream according to the SSE spec:
    /// - Lines starting with "event:" set the event type
    /// - Lines starting with "data:" accumulate data
    /// - Empty lines dispatch the accumulated event
    private func parseSSEStream(_ bytes: URLSession.AsyncBytes) async throws {
        var currentEventType: String?
        var dataBuffer = ""

        for try await line in bytes.lines {
            if Task.isCancelled { return }

            if line.hasPrefix("event:") {
                currentEventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if !dataBuffer.isEmpty { dataBuffer += "\n" }
                dataBuffer += data
            } else if line.isEmpty {
                // Empty line = dispatch event
                if let eventType = currentEventType,
                   eventType == "DEVICE_EVENT",
                   !dataBuffer.isEmpty {
                    dispatchEvent(dataBuffer)
                }
                currentEventType = nil
                dataBuffer = ""
            }
            // Lines starting with ":" are comments (keep-alive pings) — ignore
            // Lines starting with "id:" set the last event ID — we don't use it
        }
    }

    private func dispatchEvent(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        do {
            let event = try JSONDecoder().decode(SmartThingsDeviceEvent.self, from: data)
            onEvent(event)
        } catch {
            // Unrecognized event shape — skip silently. This handles
            // future event types SmartThings may add without breaking
            // the stream.
            #if DEBUG
            print("[smartthings.sse] failed to decode event: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Errors

    private enum SSEError: Error {
        case noResponse
        case httpError(Int)
    }
}

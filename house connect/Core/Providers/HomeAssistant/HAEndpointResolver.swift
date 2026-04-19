//
//  HAEndpointResolver.swift
//  house connect
//
//  Wave HH (2026-04-18) — local-vs-remote URL selection for Home Assistant.
//
//  The user can configure two base URLs in Settings → HA Setup:
//    • Local URL (e.g. http://192.168.4.23:8123) — fast, direct on home Wi-Fi.
//    • Remote URL (e.g. https://<id>.ui.nabu.casa) — used when off-network.
//
//  This resolver decides which to try first. On the first connection
//  attempt it tries local with a short timeout, falls back to remote if
//  local is unreachable, and caches the winner so subsequent reconnects
//  go straight there. When the network transitions (Wi-Fi ⇄ cellular),
//  `NWPathMonitor` clears the cache so the next attempt re-probes from
//  scratch — the "last known good" URL is probably wrong on a new path.
//
//  The resolver is additive: if only a local URL is configured, behaviour
//  matches the pre-Wave-HH provider exactly (try local, done).
//

import Foundation
import Network

/// Resolves which Home Assistant base URL to try, in which order.
/// Thread-safe — all mutable state is guarded by a serial queue.
final class HAEndpointResolver: @unchecked Sendable {

    // MARK: - Configuration

    struct Candidate: Sendable, Equatable {
        let label: String
        let url: URL
        /// `true` for the remote URL, used by the provider to publish
        /// an `isUsingRemote` signal to the UI.
        let isRemote: Bool
    }

    private let local: URL?
    private let remote: URL?
    private let probeTimeout: TimeInterval

    // MARK: - State (guarded by `stateQueue`)

    private let stateQueue = DispatchQueue(label: "ha.endpoint.resolver.state")
    private var _cachedWinner: Candidate?
    private var _currentPathSummary: String?

    // MARK: - Network observation

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "ha.endpoint.resolver.monitor")

    // MARK: - Init

    init(localURL: URL?, remoteURL: URL?, probeTimeout: TimeInterval = 3.0) {
        self.local = localURL
        self.remote = remoteURL
        self.probeTimeout = probeTimeout
        self.monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let summary = Self.summarize(path)
            self.stateQueue.async {
                if self._currentPathSummary != summary {
                    self._currentPathSummary = summary
                    self._cachedWinner = nil
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public API

    /// All configured candidates, preferred order (cache first, then local, then remote).
    var candidates: [Candidate] {
        var out: [Candidate] = []
        let cached = stateQueue.sync { _cachedWinner }

        if let cached {
            out.append(cached)
        }
        if let local, cached?.url != local {
            out.append(Candidate(label: "local", url: local, isRemote: false))
        }
        if let remote, cached?.url != remote {
            out.append(Candidate(label: "remote", url: remote, isRemote: true))
        }
        return out
    }

    /// Called by the provider after it has successfully reached a candidate.
    func recordSuccess(_ candidate: Candidate) {
        stateQueue.async {
            self._cachedWinner = candidate
        }
    }

    /// Clears the cached winner. Exposed for tests / manual reset.
    func invalidateCache() {
        stateQueue.async { self._cachedWinner = nil }
    }

    /// Current cached winner, if any — useful for the UI to show whether
    /// we're connected via local or remote.
    var currentWinner: Candidate? {
        stateQueue.sync { _cachedWinner }
    }

    /// The URL the provider is actively using (cached winner, or the
    /// first configured candidate if we haven't connected yet).
    var currentEndpoint: URL? {
        currentWinner?.url ?? local ?? remote
    }

    /// Whether the active (cached) endpoint is the remote one.
    var isUsingRemote: Bool {
        currentWinner?.isRemote ?? false
    }

    /// Timeout to use when probing each candidate during `start()`.
    var probeTimeoutSeconds: TimeInterval { probeTimeout }

    // MARK: - Helpers

    /// Produce a stable string describing the current network path so we
    /// can detect transitions. We use the interface type plus a few
    /// status bits rather than relying on identity comparisons.
    private static func summarize(_ path: NWPath) -> String {
        var bits: [String] = []
        bits.append(path.status == .satisfied ? "ok" : "down")
        if path.usesInterfaceType(.wifi) { bits.append("wifi") }
        if path.usesInterfaceType(.cellular) { bits.append("cell") }
        if path.usesInterfaceType(.wiredEthernet) { bits.append("eth") }
        if path.usesInterfaceType(.loopback) { bits.append("lo") }
        if path.isExpensive { bits.append("expensive") }
        if path.isConstrained { bits.append("constrained") }
        return bits.joined(separator: "|")
    }
}

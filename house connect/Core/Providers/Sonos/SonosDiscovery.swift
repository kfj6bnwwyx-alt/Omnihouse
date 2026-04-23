//
//  SonosDiscovery.swift
//  house connect
//
//  LAN discovery for Sonos players.
//
//  Why Bonjour instead of SSDP:
//    The canonical UPnP discovery protocol is SSDP (multicast UDP to
//    239.255.255.250:1900). iOS blocks custom multicast sends without the
//    `com.apple.developer.networking.multicast` entitlement, which requires
//    a manual request + review from Apple. Modern Sonos S2 players also
//    advertise on Bonjour (`_sonos._tcp`), and Bonjour needs neither that
//    entitlement nor any special build settings — only the Local Network
//    privacy string and a `NSBonjourServices` Info.plist entry.
//
//    When we need discovery for older S1-era players or non-Sonos UPnP
//    devices (e.g. certain Samsung TVs), we can either apply for the
//    multicast entitlement or piggyback on SmartThings' discovery since
//    the hub already sees those devices. For Phase 3a, Bonjour is enough.
//
//  Required Info.plist keys (add these in Xcode → Info tab):
//    NSLocalNetworkUsageDescription  (string)
//        "House Connect discovers Sonos players on your Wi-Fi."
//    NSBonjourServices  (array of strings)
//        - "_sonos._tcp"
//        - "_spotify-connect._tcp"   ← many Sonos speakers also advertise this
//

import Foundation
import Network

/// A Sonos player we've seen on the local network. Minimal on purpose —
/// everything else (model, software version, current track) is fetched
/// lazily once we actually want to render or control it.
struct SonosDiscoveredPlayer: Hashable, Sendable {
    /// Raw Bonjour service name. Depending on Sonos firmware this is
    /// either a clean zone label ("Kitchen") or a household-scoped form
    /// ("RINCON_B8E93766602001400@Family Room"). Keep the raw value
    /// around for debugging; use `displayName` for UI.
    let serviceName: String
    /// Resolved IPv4 host (e.g. "192.168.1.42"). Unique per player.
    let host: String
    /// Always 1400 for Sonos control; stored explicitly so we don't
    /// hardcode it at the call site.
    let port: Int

    /// Synthetic nativeID we use inside `AccessoryID.nativeID`.
    /// Host is the most stable identifier across mesh/topology changes.
    var nativeID: String { host }

    /// Friendly label for the Accessory list. Strips the `RINCON_...@`
    /// prefix some Sonos S2 firmwares prepend to their Bonjour name.
    /// Falls back to the raw service name if no `@` delimiter is found.
    var displayName: String {
        if let atIndex = serviceName.lastIndex(of: "@") {
            let tail = serviceName[serviceName.index(after: atIndex)...]
            let trimmed = tail.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return serviceName
    }
}

/// Drives an `NWBrowser` and yields a live set of discovered Sonos players.
/// Safe to start() multiple times — subsequent starts are no-ops.
@MainActor
final class SonosDiscovery {
    /// Current list of players. Observers poll this via the provider.
    private(set) var players: [SonosDiscoveredPlayer] = []

    /// Callback fired whenever `players` changes. The provider uses this
    /// to rebuild its `accessories` array and trigger the @Observable
    /// notification.
    var onChange: (([SonosDiscoveredPlayer]) -> Void)?

    /// Callback fired when the browser transitions to `.failed` — usually
    /// means Local Network permission was denied or the NSBonjourServices
    /// Info.plist entry is missing `_sonos._tcp`. Provider surfaces this
    /// to the Settings UI so the user gets an actionable message instead
    /// of a silently empty speaker list.
    var onFailure: ((String) -> Void)?

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.brentbrooks.HouseConnect.sonos.discovery")

    /// Tracks in-flight resolves so we don't fire duplicate NWConnection
    /// per bonjour result.
    private var resolving: Set<String> = []

    /// Starts Bonjour browsing. Idempotent — if already browsing, no-op.
    /// Callers that want to force a fresh scan should call `restart()`.
    func start() {
        guard browser == nil else { return }

        // We browse for `_sonos._tcp` specifically. Some speakers also
        // advertise `_spotify-connect._tcp` — cheap to add later if we
        // want to catch models that don't expose `_sonos._tcp`.
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(
            for: .bonjour(type: "_sonos._tcp", domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { state in
            // Not a lot we can do with browser state beyond logging it —
            // permission failures surface as `.failed`. The inner Task
            // owns the only reference to `self` it needs — capturing
            // weakly here (and again on the Task) keeps Swift 6 strict
            // concurrency happy, since each closure crosses a
            // concurrency domain and has to be explicit about captures.
            if case .failed(let error) = state {
                Task { @MainActor [weak self] in
                    self?.handleBrowserFailure(error)
                }
            }
        }

        browser.browseResultsChangedHandler = { results, _ in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    /// Cancels the browser and clears the player list.
    func stop() {
        browser?.cancel()
        browser = nil
        players = []
        onChange?(players)
    }

    /// Tear the browser down and start a fresh one. Used by the manual
    /// "Refresh" button in Settings so the user can re-kick discovery
    /// after granting Local Network permission, plugging in a speaker,
    /// or joining a different Wi-Fi network.
    func restart() {
        stop()
        start()
    }

    // MARK: - Result handling

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        // Bonjour only tells us "a service named X exists". To get the
        // host+port we have to resolve each endpoint via NWConnection
        // (or NWEndpoint.service → resolve). We use the connection path
        // because it's the one Apple documents for this flow.
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }
            if players.contains(where: { $0.serviceName == name }) { continue }
            if resolving.contains(name) { continue }
            resolving.insert(name)
            resolve(endpoint: result.endpoint, serviceName: name)
        }

        // Drop players whose service disappeared from the Bonjour result set.
        let stillPresent: Set<String> = Set(results.compactMap { result in
            if case .service(let name, _, _, _) = result.endpoint { return name }
            return nil
        })
        let before = players.count
        players.removeAll { !stillPresent.contains($0.serviceName) }
        if players.count != before {
            onChange?(players)
        }
    }

    private func resolve(endpoint: NWEndpoint, serviceName: String) {
        // NWConnection will upgrade a bonjour endpoint to the resolved
        // host/port the moment it hits `.ready`. We never actually send
        // bytes — just read `currentPath?.remoteEndpoint` and cancel.
        //
        // We explicitly constrain to IPv4 because Sonos speakers often
        // surface both v4 and v6 link-local addresses, and we'd rather
        // hard-pin to the v4 form than deal with URL bracket encoding
        // and interface-scoped `fe80::...%en0` syntax in URLSession.
        let parameters = NWParameters.tcp
        if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }
        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { state in
            // Same Swift 6 concern as the browser handlers above: this
            // closure runs off-main, so hop via `Task { @MainActor ... }`
            // with an explicit `[weak self]` capture rather than an
            // implicit one.
            //
            // Lifecycle notes (fixing the "already cancelled, ignoring
            // cancel" log spam seen when multiple Sonos speakers are
            // on the network):
            //   · On `.ready` we grab the remote endpoint then cancel
            //     the connection. That triggers `.cancelled` next,
            //     which we handle WITHOUT calling cancel() again.
            //   · We also clear `stateUpdateHandler` the moment we
            //     observe a terminal state so the connection releases
            //     its capture of the handler closure and can
            //     deallocate promptly.
            switch state {
            case .ready:
                let remote = connection.currentPath?.remoteEndpoint
                connection.cancel()
                Task { @MainActor [weak self] in
                    self?.recordResolved(remote: remote, serviceName: serviceName)
                }
            case .failed:
                connection.stateUpdateHandler = nil
                connection.cancel()
                Task { @MainActor [weak self] in
                    self?.resolving.remove(serviceName)
                }
            case .cancelled:
                connection.stateUpdateHandler = nil
                Task { @MainActor [weak self] in
                    self?.resolving.remove(serviceName)
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func recordResolved(remote: NWEndpoint?, serviceName: String) {
        resolving.remove(serviceName)
        guard let remote else { return }

        let host: String
        let advertisedPort: Int

        switch remote {
        case .hostPort(let h, let p):
            host = Self.stringify(host: h)
            advertisedPort = Int(p.rawValue)
        default:
            return
        }

        // CRITICAL: do not trust the Bonjour-advertised port for SOAP
        // calls. Modern Sonos firmware (S2 / S3-era) advertises port
        // 1443 — the TLS-encrypted control endpoint — as the preferred
        // port for `_sonos._tcp`. If we treat that as the SOAP port and
        // hit it with plain `http://…:1443/…`, the speaker closes the
        // TCP connection at the TLS handshake layer and we see a storm
        // of `-1005 "The network connection was lost"` errors on every
        // refresh. Every known Sonos firmware also keeps the legacy
        // plain-HTTP SOAP endpoint alive on port 1400, so we hardcode
        // that here. Bonjour is only used for discovery; the control
        // plane always targets 1400.
        let port = 1400
        if advertisedPort != port {
            print("[sonos.discovery] \(serviceName): Bonjour advertised :\(advertisedPort); using :\(port) for SOAP")
        }

        let player = SonosDiscoveredPlayer(
            serviceName: serviceName,
            host: host,
            port: port
        )

        if !players.contains(player) {
            // Replace any stale entry with the same service name before
            // appending — handles IP changes on DHCP lease renewal.
            players.removeAll { $0.serviceName == player.serviceName }
            players.append(player)
            onChange?(players)
        }
    }

    private static func stringify(host: NWEndpoint.Host) -> String {
        switch host {
        case .name(let name, _):
            return name
        case .ipv4(let addr):
            // IPv4Address.debugDescription sometimes includes the zone
            // suffix (`192.168.1.42%en0`). URL parsing doesn't like the
            // `%en0` tail, so drop anything after the percent sign.
            let raw = addr.debugDescription
            return String(raw.split(separator: "%").first ?? Substring(raw))
        case .ipv6(let addr):
            // Shouldn't happen with v4-only parameters, but handle it as
            // a best-effort fallback. Callers have to wrap the result in
            // brackets for URL construction.
            let raw = addr.debugDescription
            return String(raw.split(separator: "%").first ?? Substring(raw))
        @unknown default:
            return ""
        }
    }

    // MARK: - Failure

    private func handleBrowserFailure(_ error: NWError) {
        // Most common failure: Local Network permission denied, or the
        // NSBonjourServices Info.plist entry is missing `_sonos._tcp`.
        // Tear down the browser and hand a human-readable message to the
        // provider so it can mark itself `.denied` and surface guidance
        // in Settings instead of silently showing 0 speakers.
        browser?.cancel()
        browser = nil
        players = []
        onChange?(players)
        onFailure?(describe(error))
    }

    /// Turns an NWError into something we can show to a user. Generic
    /// fallback is fine — the Settings footer already explains the
    /// permission flow.
    private func describe(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            return "Local network error (\(code.rawValue)). Check iOS Settings → Privacy & Security → Local Network and make sure House Connect is enabled."
        default:
            return "Bonjour discovery failed: \(error.localizedDescription). Verify Local Network permission is granted."
        }
    }
}

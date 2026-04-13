//
//  SonosSOAPClient.swift
//  house connect
//
//  Minimal SOAP 1.1 helper for Sonos' UPnP control endpoints on port 1400.
//  Not a general-purpose UPnP client — we only implement the actions we
//  actually call (Play / Pause / Next / Previous / SetVolume / SetMute /
//  GetVolume / GetTransportInfo), plus one simple regex-ish response
//  extractor that reaches into the XML envelope for a single element.
//
//  Why handwrite SOAP instead of using a library: adding Gnome or some
//  UPnP SPM package for eight actions is heavier than just typing the
//  envelopes. Sonos' interface has been stable for over a decade.
//
//  Reference (Sonos' public-ish doc + UPnP A/V spec):
//    AVTransport:   urn:schemas-upnp-org:service:AVTransport:1
//                   POST /MediaRenderer/AVTransport/Control
//    RenderingControl:
//                   urn:schemas-upnp-org:service:RenderingControl:1
//                   POST /MediaRenderer/RenderingControl/Control
//

import Foundation

enum SonosSOAPError: Error, LocalizedError {
    case badStatus(Int, body: String)
    case noBody
    case invalidResponse
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let status, let body):
            // UPnP services wrap errors inside the SOAP fault detail.
            // If we can pull a friendly errorCode/description out, show
            // THAT instead of a raw HTTP-500 dump — a Sonos speaker
            // returning "Transition not available" is much more useful
            // than 200 chars of entity-encoded envelope.
            if let friendly = SonosSOAPError.formatUPnPFault(body: body) {
                return friendly
            }
            return "Sonos returned HTTP \(status): \(body.prefix(200))"
        case .noBody:
            return "Sonos returned an empty response."
        case .invalidResponse:
            return "Sonos returned a response we couldn't parse."
        case .underlying(let msg):
            return msg
        }
    }

    /// Extracts a UPnP errorCode (and optional errorDescription) from a
    /// SOAP fault body and turns it into a user-facing string. Returns
    /// nil when the body doesn't look like a UPnP fault — callers fall
    /// back to the raw HTTP dump in that case.
    ///
    /// Known codes are mapped to spec-accurate but human-readable
    /// phrases; unknown codes pass through as "UPnP error N" with any
    /// description Sonos shipped along.
    private static func formatUPnPFault(body: String) -> String? {
        // The inner XML is entity-encoded inside the s:Fault envelope
        // (&lt;errorCode&gt; etc.), but SonosSOAPClient.extractElement
        // de-escapes as part of its scrape — which works against the
        // outer envelope too. Run the scraper against the raw body
        // directly and it'll pull the unescaped errorCode out.
        let code = SonosSOAPClient.extractElement(named: "errorCode", from: body)
        guard let code, let codeInt = Int(code) else { return nil }
        let desc = SonosSOAPClient.extractElement(named: "errorDescription", from: body)
        let phrase: String = {
            switch codeInt {
            case 401: return "Invalid action."
            case 402: return "Invalid arguments."
            case 501: return "Action failed on the speaker."
            // 701 "Transition not available" is broader than it sounds:
            // Sonos returns it both when a follower refuses a transport
            // command (we route those to the coordinator now) AND when
            // the coordinator itself has nothing queued to play — an
            // empty queue can't transition to PLAYING because there's
            // no stream loaded. The user-facing message has to cover
            // both cases, because at the point we receive the error
            // we don't know which one it was without another SOAP read.
            case 701: return "Nothing is loaded to play on this speaker. Pick music from the Sonos app first, then try again."
            case 702: return "Nothing to play on that speaker."
            case 704: return "Sonos can't play that format."
            case 705: return "The speaker's transport is locked."
            case 714: return "Unsupported content type."
            case 715: return "Playback is already stopped."
            case 718: return "Invalid instance ID."
            case 800: return "Command not implemented by this speaker."
            default:
                if let desc, !desc.isEmpty {
                    return "UPnP error \(codeInt): \(desc)"
                }
                return "UPnP error \(codeInt)"
            }
        }()
        return phrase
    }
}

/// Identifies which Sonos UPnP service an action lives on. Each service
/// has its own control URL and SOAP namespace URN.
enum SonosService: String {
    case avTransport
    case renderingControl
    /// Group-wide volume and mute — distinct from per-speaker
    /// RenderingControl. `SetGroupVolume` proportionally scales every
    /// member's individual volume in the zone group, preserving the
    /// relative mix, which is how Sonos' own app implements its
    /// "one master slider for the whole group" UX. ONLY the zone
    /// group coordinator accepts these actions; followers fault.
    case groupRenderingControl
    /// Household-wide topology — tells us which speakers are bonded
    /// home-theater satellites, which rooms are casually grouped into
    /// a playback zone, and who the transport coordinator is. Lives
    /// on the player's root control endpoint (NOT /MediaRenderer).
    case zoneGroupTopology

    var controlPath: String {
        switch self {
        case .avTransport: "/MediaRenderer/AVTransport/Control"
        case .renderingControl: "/MediaRenderer/RenderingControl/Control"
        case .groupRenderingControl: "/MediaRenderer/GroupRenderingControl/Control"
        case .zoneGroupTopology: "/ZoneGroupTopology/Control"
        }
    }

    var serviceType: String {
        switch self {
        case .avTransport: "urn:schemas-upnp-org:service:AVTransport:1"
        case .renderingControl: "urn:schemas-upnp-org:service:RenderingControl:1"
        case .groupRenderingControl: "urn:schemas-upnp-org:service:GroupRenderingControl:1"
        case .zoneGroupTopology: "urn:schemas-upnp-org:service:ZoneGroupTopology:1"
        }
    }
}

@MainActor
final class SonosSOAPClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSonosSession()
    }

    /// Dedicated URLSession tuned for talking to a Sonos speaker on the
    /// local network. We deliberately DO NOT use `URLSession.shared`
    /// because it aggressively pools HTTP connections — and Sonos players
    /// drop idle TCP sockets pretty quickly, which causes
    /// `NSURLErrorNetworkConnectionLost (-1005)` on the next reuse. We've
    /// seen that exact error surface as "Family Room: The network
    /// connection was lost" in Settings → Connections.
    ///
    /// Settings of note:
    ///   - `httpMaximumConnectionsPerHost = 1` keeps the pool small
    ///     enough that stale-reuse is rare; we also retry once on -1005
    ///     in `invoke(...)` as a belt-and-braces safety net.
    ///   - `timeoutIntervalForRequest = 4` — Sonos is on the same LAN,
    ///     so if we've been waiting more than a few seconds the speaker
    ///     is genuinely unreachable; failing fast keeps the five reads
    ///     per refresh cycle bounded.
    ///   - `waitsForConnectivity = false` — same reason; we want a fast
    ///     fail on a down speaker, not a queued retry that makes the
    ///     whole refresh stall.
    ///   - `urlCache = nil` and `requestCachePolicy = .reloadIgnoring*`
    ///     — SOAP responses are stateful, never cache them.
    private static func makeSonosSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpMaximumConnectionsPerHost = 1
        cfg.timeoutIntervalForRequest = 4
        cfg.timeoutIntervalForResource = 6
        cfg.waitsForConnectivity = false
        cfg.urlCache = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: cfg)
    }

    // MARK: - High-level actions

    func play(host: String, port: Int) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "Play",
            body: """
                <InstanceID>0</InstanceID><Speed>1</Speed>
                """
        )
    }

    func pause(host: String, port: Int) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "Pause",
            body: "<InstanceID>0</InstanceID>"
        )
    }

    func stop(host: String, port: Int) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "Stop",
            body: "<InstanceID>0</InstanceID>"
        )
    }

    func next(host: String, port: Int) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "Next",
            body: "<InstanceID>0</InstanceID>"
        )
    }

    func previous(host: String, port: Int) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "Previous",
            body: "<InstanceID>0</InstanceID>"
        )
    }

    func setVolume(host: String, port: Int, percent: Int) async throws {
        let clamped = max(0, min(100, percent))
        try await invoke(
            host: host, port: port, service: .renderingControl, action: "SetVolume",
            body: """
                <InstanceID>0</InstanceID>\
                <Channel>Master</Channel>\
                <DesiredVolume>\(clamped)</DesiredVolume>
                """
        )
    }

    func setMute(host: String, port: Int, muted: Bool) async throws {
        try await invoke(
            host: host, port: port, service: .renderingControl, action: "SetMute",
            body: """
                <InstanceID>0</InstanceID>\
                <Channel>Master</Channel>\
                <DesiredMute>\(muted ? "1" : "0")</DesiredMute>
                """
        )
    }

    // MARK: - Group rendering control (group-wide volume)
    //
    // Distinct from per-speaker RenderingControl. Only the coordinator
    // of a zone group can accept GetGroupVolume / SetGroupVolume;
    // followers fault. Callers are responsible for routing the request
    // to the coordinator's host — `SonosProvider.transportTarget(for:)`
    // already does this for transport commands, and we reuse the same
    // helper for group volume. Solo speakers ALSO accept these calls
    // (they're a group of one), so we don't gate by group size here;
    // the caller decides whether it makes UI sense to display a
    // separate "Group Volume" control.
    //
    // SetGroupVolume scales every member's individual RenderingControl
    // value proportionally, preserving the relative mix the user set
    // up in the Sonos app. That's the "one master slider for the whole
    // group" UX Sonos shows natively, and why we don't just iterate
    // over members and call `setVolume` on each one.

    /// Returns the current group-wide volume (0...100). The value is
    /// the proportional master across every member in the coordinator's
    /// zone group — NOT the per-speaker RenderingControl value.
    func getGroupVolume(host: String, port: Int) async throws -> Int {
        let body = try await invoke(
            host: host, port: port,
            service: .groupRenderingControl,
            action: "GetGroupVolume",
            body: "<InstanceID>0</InstanceID>"
        )
        let raw = Self.extractElement(named: "CurrentVolume", from: body) ?? "0"
        return Int(raw) ?? 0
    }

    /// Writes a new group-wide volume on the coordinator. Sonos
    /// proportionally redistributes the change across members so the
    /// relative mix is preserved.
    func setGroupVolume(host: String, port: Int, percent: Int) async throws {
        let clamped = max(0, min(100, percent))
        try await invoke(
            host: host, port: port,
            service: .groupRenderingControl,
            action: "SetGroupVolume",
            body: """
                <InstanceID>0</InstanceID>\
                <DesiredVolume>\(clamped)</DesiredVolume>
                """
        )
    }

    // MARK: - Grouping
    //
    // Sonos' zone-group model lives on AVTransport:
    //
    //   - Joining another room's group is "set my AVTransportURI to
    //     `x-rincon:<coordinatorUUID>`". That URI is a synthetic stream
    //     the player interprets as "follow this coordinator from now on";
    //     it has no track data of its own. CurrentURIMetaData is
    //     explicitly empty — Sonos rejects DIDL-Lite here.
    //
    //   - Leaving the group is BecomeCoordinatorOfStandaloneGroup, which
    //     tears this player out of whatever group it's in and promotes
    //     it to a solo group of one. The rest of the old group rebuilds
    //     around whoever's left, and the coordinator-UUID may shuffle
    //     if the leaver WAS the coordinator — but that's Sonos' problem
    //     to solve, we just fire the command and refetch topology.
    //
    // Neither action returns meaningful data; we only care about the
    // 200 status. The caller is expected to re-run `getZoneGroupState`
    // and rebuild accessories to pick up the new grouping.

    /// Makes this player join the zone group coordinated by the given
    /// Sonos UUID (e.g. `RINCON_B8E93766602001400`). The coordinator
    /// must currently BE the coordinator of its group — Sonos will
    /// accept a non-coordinator UUID, but the semantics get weird,
    /// so `SonosProvider` always resolves the target to its group's
    /// coordinator first.
    func joinGroup(host: String, port: Int, coordinatorUUID: String) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "SetAVTransportURI",
            body: """
                <InstanceID>0</InstanceID>\
                <CurrentURI>x-rincon:\(coordinatorUUID)</CurrentURI>\
                <CurrentURIMetaData></CurrentURIMetaData>
                """
        )
    }

    /// Tears this player out of its current zone group and makes it a
    /// standalone group of one. No-op if the player is already alone,
    /// but Sonos returns 200 in that case anyway so we don't guard.
    func leaveGroup(host: String, port: Int) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport,
            action: "BecomeCoordinatorOfStandaloneGroup",
            body: "<InstanceID>0</InstanceID>"
        )
    }

    /// Writes the combined shuffle+repeat PlayMode string.
    /// Valid values per AVTransport spec:
    ///   NORMAL, REPEAT_ALL, REPEAT_ONE,
    ///   SHUFFLE_NOREPEAT, SHUFFLE, SHUFFLE_REPEAT_ONE
    /// See `SonosPlayMode.string(shuffle:repeatMode:)` for the lookup.
    func setPlayMode(host: String, port: Int, mode: String) async throws {
        try await invoke(
            host: host, port: port, service: .avTransport, action: "SetPlayMode",
            body: """
                <InstanceID>0</InstanceID>\
                <NewPlayMode>\(mode)</NewPlayMode>
                """
        )
    }

    // MARK: - Read actions

    /// Returns the AVTransport `CurrentTransportState` value, mapped to our
    /// `PlaybackState`. Used during refresh so the UI shows play/pause state.
    func getPlaybackState(host: String, port: Int) async throws -> PlaybackState {
        let body = try await invoke(
            host: host, port: port, service: .avTransport, action: "GetTransportInfo",
            body: "<InstanceID>0</InstanceID>"
        )
        let raw = Self.extractElement(named: "CurrentTransportState", from: body) ?? ""
        switch raw {
        case "PLAYING": return .playing
        case "PAUSED_PLAYBACK": return .paused
        case "STOPPED": return .stopped
        case "TRANSITIONING": return .transitioning
        default: return .unknown
        }
    }

    /// Returns the current master volume as a 0...100 integer.
    func getVolume(host: String, port: Int) async throws -> Int {
        let body = try await invoke(
            host: host, port: port, service: .renderingControl, action: "GetVolume",
            body: """
                <InstanceID>0</InstanceID>\
                <Channel>Master</Channel>
                """
        )
        let raw = Self.extractElement(named: "CurrentVolume", from: body) ?? "0"
        return Int(raw) ?? 0
    }

    /// Returns the current mute state.
    func getMute(host: String, port: Int) async throws -> Bool {
        let body = try await invoke(
            host: host, port: port, service: .renderingControl, action: "GetMute",
            body: """
                <InstanceID>0</InstanceID>\
                <Channel>Master</Channel>
                """
        )
        let raw = Self.extractElement(named: "CurrentMute", from: body) ?? "0"
        return raw == "1"
    }

    /// Returns the raw Sonos PlayMode string — one of the six combined
    /// shuffle+repeat tokens. The SonosProvider feeds this through
    /// `SonosPlayMode.parse(_:)` to get two independent booleans.
    func getPlayMode(host: String, port: Int) async throws -> String {
        let body = try await invoke(
            host: host, port: port, service: .avTransport, action: "GetTransportSettings",
            body: "<InstanceID>0</InstanceID>"
        )
        return Self.extractElement(named: "PlayMode", from: body) ?? "NORMAL"
    }

    // MARK: - Topology

    /// Fetches the household-wide zone group topology from a single
    /// reachable player. Every Sonos speaker on a given household knows
    /// the full topology (they gossip it over SSDP eventing internally),
    /// so we only need to ask ONE player — even if we call a satellite
    /// or a player in a zone group, we still get the full picture back.
    ///
    /// The response from `GetZoneGroupState` wraps the actual topology
    /// XML inside an XML-escaped `<ZoneGroupState>` string element. We
    /// pull that out and hand it to `SonosTopologyParser` — a real
    /// `XMLParser`-based walker, because the payload is attribute-heavy
    /// and the two-line string scraper we use elsewhere can't read
    /// attribute values.
    func getZoneGroupState(host: String, port: Int) async throws -> SonosTopology {
        let body = try await invoke(
            host: host, port: port,
            service: .zoneGroupTopology,
            action: "GetZoneGroupState",
            body: "" // GetZoneGroupState takes no input parameters
        )
        // Diagnostic: log the first chunk of the raw SOAP response so we
        // can see exactly what the speaker returned. Different firmware
        // versions return slightly different envelope shapes (some
        // inline the topology, some wrap it as an entity-encoded string
        // inside <ZoneGroupState>) and we need visibility into which
        // variant this household speaks.
        #if DEBUG
        print("[sonos.soap] GetZoneGroupState raw body (\(body.count) chars):")
        print(String(body.prefix(800)))
        #endif

        // Sonos escapes the inner topology XML twice — once for the SOAP
        // envelope itself, and once more to stuff it inside a string
        // element. `extractElement` already handles common XML entity
        // decoding so after extraction we can feed the result straight
        // into XMLParser.
        guard let inner = Self.extractElement(named: "ZoneGroupState", from: body),
              !inner.isEmpty else {
            #if DEBUG
            print("[sonos.soap] ⚠️ no <ZoneGroupState> element found in response")
            #endif
            return SonosTopology(zoneGroups: [])
        }
        #if DEBUG
        print("[sonos.soap] inner ZoneGroupState (\(inner.count) chars):")
        print(String(inner.prefix(1200)))
        #endif
        let topology = SonosTopologyParser.parse(inner)
        #if DEBUG
        print("[sonos.soap] parser produced \(topology.zoneGroups.count) zone group(s)")
        #endif
        return topology
    }

    // MARK: - Now Playing

    /// Snapshot of what's currently playing, pulled from GetPositionInfo.
    /// The Sonos response wraps the metadata in DIDL-Lite inside a CDATA
    /// block keyed as `TrackMetaData`; we unescape + scrape it for the
    /// fields we care about.
    struct TrackSnapshot: Sendable {
        var title: String?
        var artist: String?
        var album: String?
        /// Relative art path (e.g. `/getaa?s=1&u=...`). The provider
        /// resolves this against the player's host:port before handing
        /// it to the UI.
        var albumArtRelativePath: String?

        // Phase 3a+ extended fields — extracted from DIDL-Lite and
        // the outer SOAP response. All optional, degrade gracefully.
        var albumArtist: String?        // r:albumArtist (preferred display artist)
        var trackNumber: Int?           // upnp:originalTrackNumber
        var duration: String?           // TrackDuration from SOAP response (e.g. "0:03:42")
        var streamSource: String?       // r:streamContent or service name
    }

    /// Pulls current track metadata from AVTransport::GetPositionInfo.
    /// Used by SonosProvider during status refresh to populate the
    /// `.nowPlaying(...)` capability. Returns an empty snapshot when
    /// nothing is playing — the caller decides whether to publish it.
    func getPositionInfo(host: String, port: Int) async throws -> TrackSnapshot {
        let body = try await invoke(
            host: host, port: port, service: .avTransport, action: "GetPositionInfo",
            body: "<InstanceID>0</InstanceID>"
        )
        // Diagnostic: log the raw SOAP body (first chunk) so we can see
        // what Sonos is actually returning when users report "I can't
        // see what's playing". Different streams (Spotify vs AirPlay vs
        // line-in) hand back wildly different envelope shapes, and the
        // only way to know which scraper branch needs more slack is to
        // see the response text itself.
        #if DEBUG
        print("[sonos.soap] GetPositionInfo @ \(host):\(port) → \(body.count) chars")
        if body.count < 1500 {
            print("[sonos.soap] raw body: \(body)")
        } else {
            print("[sonos.soap] raw body head: \(body.prefix(800))")
        }
        #endif

        // TrackMetaData is DIDL-Lite XML embedded as an XML-escaped string.
        // extractElement already de-escapes common entities, so after
        // extraction we get real XML we can scrape again.
        guard let meta = Self.extractElement(named: "TrackMetaData", from: body),
              !meta.isEmpty, meta != "NOT_IMPLEMENTED" else {
            #if DEBUG
            print("[sonos.soap] ⚠️ no usable TrackMetaData (empty or NOT_IMPLEMENTED)")
            #endif
            return TrackSnapshot()
        }
        #if DEBUG
        print("[sonos.soap] TrackMetaData (\(meta.count) chars): \(meta.prefix(500))")
        #endif

        // DIDL-Lite uses namespaced element names (`dc:title`, `dc:creator`,
        // `upnp:album`, `upnp:albumArtURI`). Our scraper is not
        // namespace-aware on purpose, so we match the qualified names
        // directly — they're stable across every Sonos firmware.
        let title = Self.extractElement(named: "dc:title", from: meta)
        let artist = Self.extractElement(named: "dc:creator", from: meta)
        let album = Self.extractElement(named: "upnp:album", from: meta)
        let art = Self.extractElement(named: "upnp:albumArtURI", from: meta)

        // Extended metadata — Phase 3a+
        let albumArtist = Self.extractElement(named: "r:albumArtist", from: meta)
        let trackNumStr = Self.extractElement(named: "upnp:originalTrackNumber", from: meta)
        let streamContent = Self.extractElement(named: "r:streamContent", from: meta)

        // Duration lives outside DIDL-Lite, in the outer SOAP response.
        let durationRaw = Self.extractElement(named: "TrackDuration", from: body)
        let duration = (durationRaw != nil && durationRaw != "NOT_IMPLEMENTED") ? durationRaw : nil

        #if DEBUG
        print("[sonos.soap] parsed → title=\(title ?? "nil") artist=\(artist ?? "nil") album=\(album ?? "nil") art=\(art ?? "nil")")
        #endif
        return TrackSnapshot(
            title: title?.isEmpty == false ? title : nil,
            artist: artist?.isEmpty == false ? artist : nil,
            album: album?.isEmpty == false ? album : nil,
            albumArtRelativePath: art?.isEmpty == false ? art : nil,
            albumArtist: albumArtist?.isEmpty == false ? albumArtist : nil,
            trackNumber: trackNumStr.flatMap(Int.init),
            duration: duration,
            streamSource: streamContent?.isEmpty == false ? streamContent : nil
        )
    }

    // MARK: - Transport

    /// Sends a SOAP envelope and returns the response body as a String.
    /// `innerBody` is the inner XML fragment inside `<u:{Action}>...</u:{Action}>`.
    @discardableResult
    private func invoke(
        host: String,
        port: Int,
        service: SonosService,
        action: String,
        body innerBody: String
    ) async throws -> String {
        // Safety net: if an IPv6 address sneaks past the v4-only
        // constraint in discovery, wrap it in brackets so URL parsing
        // succeeds. IPv4 strings never contain `:`, so this check is
        // unambiguous.
        let hostForURL = host.contains(":") ? "[\(host)]" : host
        guard let url = URL(string: "http://\(hostForURL):\(port)\(service.controlPath)") else {
            throw SonosSOAPError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(service.serviceType)#\(action)\"", forHTTPHeaderField: "SOAPAction")
        request.timeoutInterval = 5

        let envelope = """
            <?xml version="1.0" encoding="utf-8"?>\
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
            <s:Body>\
            <u:\(action) xmlns:u="\(service.serviceType)">\(innerBody)</u:\(action)>\
            </s:Body>\
            </s:Envelope>
            """
        request.httpBody = envelope.data(using: .utf8)

        // One-shot retry on the narrow set of URLSession errors that
        // indicate a stale pooled connection rather than a real
        // "speaker isn't reachable" condition. -1005 (connection lost)
        // is the specific code Sonos users see when a reused HTTP socket
        // went cold between refreshes. -1001 (timed out) and -1004
        // (can't connect) get the same treatment because they can also
        // be transient when the pool is involved; a genuine
        // unreachability still fails the second time and we bubble it
        // up normally.
        let retriableCodes: Set<Int> = [
            NSURLErrorNetworkConnectionLost,   // -1005
            NSURLErrorTimedOut,                // -1001
            NSURLErrorCannotConnectToHost,     // -1004
        ]

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where retriableCodes.contains(error.code.rawValue) {
            // Immediate retry — no backoff. The whole point is that the
            // first attempt died on a closed socket and we just need to
            // open a new one. A pause would only make the user wait.
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw SonosSOAPError.underlying(error.localizedDescription)
            }
        } catch {
            throw SonosSOAPError.underlying(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SonosSOAPError.invalidResponse
        }
        let bodyString = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw SonosSOAPError.badStatus(http.statusCode, body: bodyString)
        }
        return bodyString
    }

    // MARK: - Tiny XML scraper

    /// Pulls the text content of the FIRST matching element by name out of
    /// an XML blob. We deliberately avoid a real XMLParser here because the
    /// values we care about (CurrentTransportState, CurrentVolume, etc.)
    /// are plain string scalars — a two-line scrape is easier to read and
    /// cheaper to unit-test than a parser delegate.
    ///
    /// Intentionally non-namespace-aware: Sonos' SOAP responses use flat
    /// element names inside the service-specific inner body.
    ///
    /// `nonisolated` because this is a pure string transform with no
    /// captured state — `SonosSOAPClient` is `@MainActor`-isolated as
    /// a whole, but we want this helper callable from free functions
    /// like `SonosSOAPError.formatUPnPFault` that synthesize friendly
    /// error descriptions outside the actor.
    nonisolated static func extractElement(named name: String, from xml: String) -> String? {
        guard let openRange = xml.range(of: "<\(name)>") else { return nil }
        guard let closeRange = xml.range(of: "</\(name)>", range: openRange.upperBound..<xml.endIndex) else {
            return nil
        }
        let value = xml[openRange.upperBound..<closeRange.lowerBound]
        // Responses may be XML-escaped (e.g. `&lt;`); decode the common ones.
        return String(value)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}

// MARK: - Topology model
//
// Lives in this file (not a new source file) so the user doesn't have
// to add another file to the Xcode target. Pure data — no SwiftUI, no
// @Observable, safe to build / hash / compare in tests.

/// Household-wide zone group state as reported by `GetZoneGroupState`.
/// A Sonos household contains N zone groups; each zone group contains
/// one or more visible `ZoneGroupMember` rooms plus zero or more
/// bonded satellites welded into each room.
struct SonosTopology: Sendable, Hashable {
    let zoneGroups: [SonosZoneGroup]
}

/// One zone group — a set of rooms currently playing the same thing.
/// The `coordinatorUUID` is the room whose AVTransport service is
/// driving playback; other members follow it. A "not currently in any
/// group" room is reported as a zone group of size one where the only
/// member IS the coordinator.
struct SonosZoneGroup: Sendable, Hashable {
    let groupID: String            // e.g. "RINCON_ARC01400:1234567890"
    let coordinatorUUID: String    // matches one of the member UUIDs
    var members: [SonosZoneGroupMember]
}

/// A visible room in a zone group. "Visible" means it should render
/// as a top-level tile — as opposed to a bonded satellite, which is
/// folded into its parent member's `satellites` array and NOT
/// surfaced separately.
struct SonosZoneGroupMember: Sendable, Hashable {
    /// Native Sonos UUID, e.g. `RINCON_B8E93766602001400`.
    let uuid: String
    /// Room label the user sees in the Sonos app ("Family Room").
    let zoneName: String
    /// IP host extracted from the member's `Location` URL. Used to
    /// cross-reference against `SonosDiscoveredPlayer.host` so we know
    /// which Bonjour-discovered player IS this topology member.
    let locationHost: String?
    /// Bonded satellites welded to this member. Each satellite is ALSO
    /// a real Sonos player that shows up on Bonjour, but it should be
    /// hidden from the top-level devices list — the bar/coordinator
    /// represents the whole bonded set in the UI.
    var satellites: [SonosSatellite]
}

/// A bonded home-theater satellite — a Sub, a rear surround speaker,
/// a paired stereo twin. Not visible as its own tile; surfaced only
/// as an entry in the parent member's bonded-parts row.
struct SonosSatellite: Sendable, Hashable {
    let uuid: String
    let zoneName: String
    /// The raw `ChannelMapSet` attribute value, e.g. `RINCON_SUB:SW,SW`
    /// or `RINCON_ONE_L:LF,LF`. Contains the channel role we decode
    /// into a friendly label via `displayLabel`.
    let channelMapSet: String
    /// IP host of this satellite, so rebuild can mark it as hidden.
    let locationHost: String?

    /// Human label derived from the ChannelMapSet role suffix.
    /// Empirically observed roles from Sonos firmware:
    ///   SW           → "Sub"
    ///   LF           → "Rear Left"
    ///   RF           → "Rear Right"
    ///   LR / RR      → same as LF / RF (older firmware)
    ///   LF,LR        → treat as a rear combo; use the first role
    /// Anything we don't recognise falls through to "Satellite" so a
    /// tile never has a blank entry.
    var displayLabel: String {
        guard let colonIndex = channelMapSet.firstIndex(of: ":") else {
            return "Satellite"
        }
        let rolePart = channelMapSet[channelMapSet.index(after: colonIndex)...]
        let firstRole = rolePart
            .split(separator: ",", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces)
            .uppercased() ?? ""
        switch firstRole {
        case "SW":       return "Sub"
        case "LF", "LR": return "Rear Left"
        case "RF", "RR": return "Rear Right"
        case "":         return "Satellite"
        default:         return firstRole.capitalized
        }
    }
}

// MARK: - Topology parser
//
// Attribute-heavy XML, so we can't reuse `extractElement` (which only
// reads element text content). A tiny `XMLParser` delegate walks the
// document in one pass, building the model tree.
//
// Hierarchy we care about:
//   <ZoneGroupState>
//     <ZoneGroups>
//       <ZoneGroup Coordinator="..." ID="...">
//         <ZoneGroupMember UUID="..." ZoneName="..." Location="..." Invisible="0|1">
//           <Satellite UUID="..." ChannelMapSet="..." Location="..."/>
//           ...
//         </ZoneGroupMember>
//         ...
//       </ZoneGroup>
//       ...
//     </ZoneGroups>
//   </ZoneGroupState>
//
// We drop `<ZoneGroupMember Invisible="1">` entries entirely — those
// are the "phantom" entries Sonos uses to represent bonded satellites
// at the group level. The real per-satellite data comes from the
// nested `<Satellite>` children.

final class SonosTopologyParser: NSObject, XMLParserDelegate {
    private var zoneGroups: [SonosZoneGroup] = []
    private var currentGroup: SonosZoneGroup?
    private var currentMember: SonosZoneGroupMember?

    static func parse(_ xml: String) -> SonosTopology {
        let parser = SonosTopologyParser()
        guard let data = xml.data(using: .utf8) else {
            return SonosTopology(zoneGroups: [])
        }
        let xp = XMLParser(data: data)
        xp.delegate = parser
        _ = xp.parse()
        return SonosTopology(zoneGroups: parser.zoneGroups)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "ZoneGroup":
            currentGroup = SonosZoneGroup(
                groupID: attributeDict["ID"] ?? "",
                coordinatorUUID: attributeDict["Coordinator"] ?? "",
                members: []
            )

        case "ZoneGroupMember":
            // Drop invisible group-level entries (Sonos' phantom rows
            // for bonded sub/rears that don't deserve their own tile).
            // The real satellite metadata comes from nested <Satellite>
            // children under a VISIBLE member.
            if attributeDict["Invisible"] == "1" { return }
            currentMember = SonosZoneGroupMember(
                uuid: attributeDict["UUID"] ?? "",
                zoneName: attributeDict["ZoneName"] ?? "",
                locationHost: Self.host(from: attributeDict["Location"]),
                satellites: []
            )

        case "Satellite":
            guard var member = currentMember else { return }
            member.satellites.append(
                SonosSatellite(
                    uuid: attributeDict["UUID"] ?? "",
                    zoneName: attributeDict["ZoneName"] ?? "",
                    channelMapSet: attributeDict["ChannelMapSet"] ?? "",
                    locationHost: Self.host(from: attributeDict["Location"])
                )
            )
            // Struct, so we have to write the mutated copy back.
            currentMember = member

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "ZoneGroupMember":
            if let member = currentMember {
                currentGroup?.members.append(member)
                currentMember = nil
            }

        case "ZoneGroup":
            if let group = currentGroup {
                zoneGroups.append(group)
                currentGroup = nil
            }

        default:
            break
        }
    }

    /// Extracts the host part of a Sonos `Location` URL. Typical values
    /// look like `http://192.168.1.42:1400/xml/device_description.xml`;
    /// we only need the `192.168.1.42` piece so the provider can cross-
    /// reference against `SonosDiscoveredPlayer.host`.
    private static func host(from location: String?) -> String? {
        guard let location, !location.isEmpty else { return nil }
        // Prefer URLComponents — it's robust to bracketed IPv6 hosts
        // that a naive substring would chop wrong.
        if let components = URLComponents(string: location), let host = components.host {
            return host
        }
        return nil
    }
}

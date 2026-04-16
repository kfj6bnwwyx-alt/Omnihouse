//
//  HomeAssistantDiscovery.swift
//  house connect
//
//  Bonjour/mDNS discovery for Home Assistant instances on the local
//  network. HA advertises as _home-assistant._tcp. We resolve the
//  service to get the IP, port, and metadata (location_name, version,
//  internal_url).
//

import Foundation
import Network

/// A discovered HA instance on the local network.
struct DiscoveredHAInstance: Identifiable, Hashable, Sendable {
    let id: String          // uuid from TXT record
    let name: String        // location_name from TXT record
    let url: URL            // internal_url or constructed from host:port
    let version: String     // HA version
}

/// Browses the local network for Home Assistant instances using NWBrowser.
@MainActor
@Observable
final class HomeAssistantDiscovery {
    private(set) var instances: [DiscoveredHAInstance] = []
    private(set) var isSearching: Bool = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    /// Start scanning. Automatically stops after `timeout` seconds.
    func startScan(timeout: TimeInterval = 10) {
        instances.removeAll()
        isSearching = true

        let params = NWParameters()
        params.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_home-assistant._tcp", domain: nil),
            using: params
        )

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard case .failed = state else { return }
                self?.stopScan()
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.processResults(results)
            }
        }

        self.browser = browser
        browser.start(queue: .main)

        // Auto-stop after timeout
        stopTask = Task {
            try? await Task.sleep(for: .seconds(timeout))
            stopScan()
        }
    }

    func stopScan() {
        browser?.cancel()
        browser = nil
        isSearching = false
        stopTask?.cancel()
        stopTask = nil
    }

    private func processResults(_ results: Set<NWBrowser.Result>) {
        var found: [DiscoveredHAInstance] = []

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            // Extract TXT record data
            let txtDict = extractTXTRecord(from: result.metadata)

            let uuid = txtDict["uuid"] ?? name
            let locationName = txtDict["location_name"] ?? name
            let version = txtDict["version"] ?? "unknown"

            // Build URL from internal_url or base_url
            let urlString = txtDict["internal_url"] ?? txtDict["base_url"] ?? "http://\(name):8123"
            guard let url = URL(string: urlString) else { continue }

            found.append(DiscoveredHAInstance(
                id: uuid,
                name: locationName,
                url: url,
                version: version
            ))
        }

        instances = found
    }

    /// Parse TXT record metadata from an NWBrowser result.
    /// NWTXTRecord subscript returns String? directly on modern SDKs.
    private func extractTXTRecord(from metadata: NWBrowser.Result.Metadata) -> [String: String] {
        guard case .bonjour(let txtRecord) = metadata else { return [:] }

        var dict: [String: String] = [:]
        let keys = ["location_name", "uuid", "version", "internal_url", "base_url"]
        for key in keys {
            if let value: String = txtRecord[key] {
                dict[key] = value
            }
        }
        return dict
    }
}

import Foundation
import Network

struct DiscoveredServer: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int

    var url: URL {
        URL(string: "http://\(host):\(port)")!
    }
}

/// Discovers Home Assistant instances on the local network via mDNS/Bonjour.
@Observable
@MainActor
final class ServerDiscovery {

    private(set) var servers: [DiscoveredServer] = []
    private(set) var isScanning = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    // Can't call @MainActor stopDiscovery() from nonisolated deinit — cancel directly.
    deinit { browser?.cancel(); timeoutTask?.cancel() }

    func startDiscovery() {
        servers = []
        isScanning = true

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_home-assistant._tcp", domain: nil), using: params)

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .failed:
                    self.stopDiscovery()
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor in
                for result in results {
                    if case let .service(name, _, _, _) = result.endpoint {
                        guard !self.servers.contains(where: { $0.name == name }) else { continue }
                        self.resolveEndpoint(result.endpoint, name: name)
                    }
                }
            }
        }

        browser.start(queue: .main)
        self.browser = browser

        // Auto-stop after 5 seconds
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            stopDiscovery()
        }
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isScanning = false
    }

    // MARK: - Private

    #if DEBUG
    static func preview(servers: [DiscoveredServer], isScanning: Bool = false) -> ServerDiscovery {
        let discovery = ServerDiscovery()
        discovery.servers = servers
        discovery.isScanning = isScanning
        return discovery
    }
    #endif

    private func resolveEndpoint(_ endpoint: NWEndpoint, name: String) {
        // Force IPv4 — link-local IPv6 (fe80::) is useless for HTTP URLs
        let params = NWParameters.tcp
        if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }

        let connection = NWConnection(to: endpoint, using: params)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .ready:
                    if let path = connection.currentPath,
                       let remoteEndpoint = path.remoteEndpoint,
                       case let .hostPort(host, port) = remoteEndpoint,
                       case .ipv4 = host {
                        // NWEndpoint.Host may include interface scope (e.g. "192.168.1.1%en0") — strip it
                        let hostString = "\(host)".split(separator: "%").first.map(String.init) ?? "\(host)"
                        let server = DiscoveredServer(
                            name: name,
                            host: hostString,
                            port: Int(port.rawValue)
                        )
                        if !self.servers.contains(where: { $0.host == hostString }) {
                            self.servers.append(server)
                        }
                    }
                    connection.cancel()
                case .failed, .cancelled:
                    connection.cancel()
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }
}

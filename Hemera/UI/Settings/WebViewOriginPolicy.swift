import Foundation

/// Takes plain values rather than a `WKSecurityOrigin`, which has no public initialiser to test with.
struct WebViewOriginPolicy: Equatable {

    private let scheme: String
    private let host: String
    private let port: Int

    init(serverURL: URL) {
        let scheme = (serverURL.scheme ?? "").lowercased()
        self.scheme = scheme
        self.host = (serverURL.host() ?? "").lowercased()
        self.port = Self.resolvedPort(serverURL.port ?? 0, scheme: scheme)
    }

    /// Whether a navigation target is the server itself, over its own scheme or an https upgrade.
    func allows(_ url: URL?) -> Bool {
        guard let url, let host = url.host(), !host.isEmpty else { return false }
        let scheme = (url.scheme ?? "").lowercased()
        guard scheme == "http" || scheme == "https" else { return false }
        return matches(scheme: scheme, host: host, port: url.port ?? 0)
    }

    /// Whether a frame's origin is the server's. A `port` of 0 means the scheme's default.
    func allows(scheme: String, host: String, port: Int) -> Bool {
        guard !host.isEmpty else { return false }
        return matches(scheme: scheme, host: host, port: port)
    }

    // MARK: - Private

    private func matches(scheme: String, host: String, port: Int) -> Bool {
        let scheme = scheme.lowercased()
        guard host.lowercased() == self.host else { return false }
        let resolved = Self.resolvedPort(port, scheme: scheme)
        guard scheme != self.scheme else { return resolved == self.port }
        /**
         An http address answering over https is the same server behind a proxy that redirects,
         and refusing it would strand the webview blank. A downgrade is not the same server.
        */
        guard scheme == "https", self.scheme == "http" else { return false }
        return resolved == self.port || (self.port == 80 && resolved == 443)
    }

    /// `WKSecurityOrigin` reports 0 for a default port, so both sides are resolved before comparing.
    private static func resolvedPort(_ port: Int, scheme: String) -> Int {
        guard port == 0 else { return port }
        switch scheme {
        case "https": return 443
        case "http": return 80
        default: return 0
        }
    }
}

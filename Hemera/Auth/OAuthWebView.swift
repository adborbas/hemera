import SwiftUI
import WebKit

/// Ephemeral WKWebView that loads the HA OAuth authorize page and intercepts
/// the redirect to the same-origin callback URL.
struct OAuthWebView: UIViewRepresentable {

    let url: URL
    let redirectURI: String
    let onCallback: (URL) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(redirectURI: redirectURI, onCallback: onCallback)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let redirectURI: String
        let onCallback: (URL) -> Void
        private var didFire = false

        init(redirectURI: String, onCallback: @escaping (URL) -> Void) {
            self.redirectURI = redirectURI
            self.onCallback = onCallback
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               url.absoluteString.hasPrefix(redirectURI),
               !didFire {
                didFire = true
                onCallback(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

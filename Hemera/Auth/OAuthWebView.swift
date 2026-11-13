import SwiftUI
import WebKit

/// Ephemeral WKWebView that loads the HA OAuth authorize page and intercepts
/// the redirect to the same-origin callback URL.
struct OAuthWebView: UIViewRepresentable {

    let url: URL
    let redirectURI: String
    let onCallback: (URL) -> Void
    /// The sign-in page could not be loaded — a probe can't predict a TLS failure or a server that drops mid-flow.
    let onFailure: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.accessibilityLabel = Localization.loading
        spinner.isUserInteractionEnabled = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        webView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
        ])
        context.coordinator.loadingObservation = webView.observe(\.isLoading) { webView, _ in
            MainActor.assumeIsolated {
                if webView.isLoading { spinner.startAnimating() } else { spinner.stopAnimating() }
            }
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(redirectURI: redirectURI, onCallback: onCallback, onFailure: onFailure)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let redirectURI: String
        let onCallback: (URL) -> Void
        let onFailure: () -> Void
        var loadingObservation: NSKeyValueObservation?
        private var didFire = false

        init(redirectURI: String, onCallback: @escaping (URL) -> Void, onFailure: @escaping () -> Void) {
            self.redirectURI = redirectURI
            self.onCallback = onCallback
            self.onFailure = onFailure
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

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        /**
         Intercepting the callback cancels its navigation, which WebKit reports as a failure —
         so a cancellation after the code is in hand is the success path, not an error.
        */
        private func report(_ error: Error) {
            guard !didFire, (error as NSError).code != NSURLErrorCancelled else { return }
            didFire = true
            onFailure()
        }
    }
}

private extension OAuthWebView {
    enum Localization {
        static let loading = String(
            localized: "Loading",
            comment: "Accessibility label for the spinner shown while the Home Assistant sign-in page loads"
        )
    }
}

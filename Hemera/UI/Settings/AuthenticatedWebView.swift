import SwiftUI
import WebKit

/// WKWebView that authenticates with HA's external auth protocol.
///
/// Defines `window.externalApp` with bridge functions that forward to native
/// WKScriptMessageHandlers. Handles the `externalBus` message protocol
/// (responding to `config/get` etc.) and the `getExternalAuth` token flow.
struct AuthenticatedWebView: UIViewRepresentable {

    let url: URL
    let tokenProvider: () async throws -> String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        let bridge = WKUserScript(
            source: """
            window.externalApp = {
                getExternalAuth: function(payload) {
                    var opts = typeof payload === 'string' ? JSON.parse(payload) : payload;
                    window.webkit.messageHandlers.getExternalAuth.postMessage(opts);
                },
                revokeExternalAuth: function(payload) {
                    var opts = typeof payload === 'string' ? JSON.parse(payload) : payload;
                    window.webkit.messageHandlers.revokeExternalAuth.postMessage(opts);
                },
                externalBus: function(payload) {
                    window.webkit.messageHandlers.externalBus.postMessage(
                        typeof payload === 'string' ? JSON.parse(payload) : payload
                    );
                }
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bridge)
        config.userContentController.add(context.coordinator, name: "getExternalAuth")
        config.userContentController.add(context.coordinator, name: "revokeExternalAuth")
        config.userContentController.add(context.coordinator, name: "externalBus")

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView

        let requestURL: URL
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = (components.queryItems ?? []) + [
                URLQueryItem(name: "external_auth", value: "1")
            ]
            requestURL = components.url ?? url
        } else {
            requestURL = url
        }
        webView.load(URLRequest(url: requestURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(tokenProvider: tokenProvider)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        let tokenProvider: () async throws -> String

        init(tokenProvider: @escaping () async throws -> String) {
            self.tokenProvider = tokenProvider
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "getExternalAuth":
                handleGetExternalAuth(message.body)
            case "revokeExternalAuth":
                handleRevokeExternalAuth(message.body)
            case "externalBus":
                handleExternalBus(message.body)
            default:
                break
            }
        }

        // MARK: - External Auth

        private func handleGetExternalAuth(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let callback = dict["callback"] as? String else { return }

            Task { @MainActor in
                do {
                    let token = try await self.tokenProvider()
                    let js = "\(callback)(true, {\"access_token\": \"\(token)\", \"expires_in\": 1800});"
                    try await self.webView?.evaluateJavaScript(js)
                } catch {
                    _ = try? await self.webView?.evaluateJavaScript("\(callback)(false);")
                }
            }
        }

        private func handleRevokeExternalAuth(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let callback = dict["callback"] as? String else { return }
            Task { @MainActor in
                _ = try? await self.webView?.evaluateJavaScript("\(callback)(true);")
            }
        }

        // MARK: - External Bus

        private func handleExternalBus(_ body: Any) {
            guard let msg = body as? [String: Any],
                  let id = msg["id"],
                  let type = msg["type"] as? String else { return }

            switch type {
            case "config/get":
                sendBusResult(id: id, result: [
                    "hasSettingsScreen": false,
                    "canWriteTag": false,
                    "hasExoPlayer": false,
                    "canCommissionMatter": false,
                    "canImportThreadCredentials": false,
                    "hasAssist": false,
                    "hasBarCodeScanner": false,
                ])
            case "config_screen/show":
                break // no-op, we handle settings natively
            default:
                // Acknowledge unknown messages so frontend doesn't hang
                sendBusResult(id: id, result: nil)
            }
        }

        private func sendBusResult(id: Any, result: [String: Any]?) {
            Task { @MainActor in
                var response: [String: Any] = [
                    "id": id,
                    "type": "result",
                    "success": true,
                ]
                if let result {
                    response["result"] = result
                }
                guard let data = try? JSONSerialization.data(withJSONObject: response),
                      let json = String(data: data, encoding: .utf8) else { return }
                _ = try? await self.webView?.evaluateJavaScript("window.externalBus(\(json));")
            }
        }
    }
}

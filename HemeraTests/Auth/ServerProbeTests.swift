import Foundation
import Testing
@testable import Hemera

/// The probe gates sign-in, so a payload it refuses is a server nobody can log into.
@MainActor
@Suite(.serialized)
struct ServerProbeTests {

    private func probe(_ json: String, status: Int = 200) async -> Error? {
        let url = URL(string: "https://ha.example.com")!
        StubURLProtocol.body = Data(json.utf8)
        StubURLProtocol.status = status
        let probe = ServerProbe(session: StubURLProtocol.session)
        do {
            try await probe.probe(url, timeout: 2)
            return nil
        } catch {
            return error
        }
    }

    @Test
    func probe_acceptsThePre2024_2BareArray() async {
        let error = await probe(#"[{"name":"Home Assistant Local","id":null,"type":"homeassistant"}]"#)
        #expect(error == nil)
    }

    @Test
    func probe_acceptsThe2024_2Wrapper() async {
        let error = await probe(#"{"providers":[{"name":"Home Assistant Local","id":null,"type":"homeassistant"}],"preselect_remember_me":false}"#)
        #expect(error == nil)
    }

    @Test
    func probe_rejectsSomethingThatIsNotHomeAssistant() async {
        let error = await probe("<html>Example Domain</html>")
        #expect(error as? AuthError == .notHomeAssistant)
    }

    @Test
    func probe_rejectsANonOKStatus() async {
        let error = await probe(#"{"providers":[]}"#, status: 404)
        #expect(error as? AuthError == .notHomeAssistant)
    }
}

// MARK: - Stub transport

final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var status = 200

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.status,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

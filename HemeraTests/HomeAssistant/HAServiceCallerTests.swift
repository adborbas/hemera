import Foundation
import Testing
import HAKit
@testable import Hemera

@MainActor
struct HAServiceCallerTests {

    // MARK: - Error Classification

    @Test
    func classifyError_externalError_returnsServer() {
        let error: HAError = .external(.init(code: "not_found", message: "Service not found"))
        #expect(HAServiceCaller.classifyError(error) == .server)
    }

    @Test
    func classifyError_underlyingError_returnsConnection() {
        let error: HAError = .underlying(NSError(domain: "test", code: -1))
        #expect(HAServiceCaller.classifyError(error) == .connection)
    }

    @Test
    func classifyError_internalError_returnsConnection() {
        let error: HAError = .internal(debugDescription: "parse failure")
        #expect(HAServiceCaller.classifyError(error) == .connection)
    }

    @Test
    func classifyError_unknownError_returnsConnection() {
        struct UnknownError: Error {}
        #expect(HAServiceCaller.classifyError(UnknownError()) == .connection)
    }
}

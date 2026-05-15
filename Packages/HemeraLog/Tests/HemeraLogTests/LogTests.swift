import Synchronization
import Testing
@testable import HemeraLog

@Suite(.serialized)
struct LogTests {

    init() {
        Log.removeAllDestinations()
    }

    @Test func addDestination_dispatchesToRegisteredDestination() {
        let spy = SpyDestination()
        Log.addDestination(spy)

        Log.info("hello from test", file: "Test.swift", function: "test()", line: 99)

        let received = spy.received
        #expect(received.count == 1)

        let entry = received.last!
        #expect(entry.level == .info)
        #expect(entry.message == "hello from test")
        #expect(entry.file == "Test.swift")
        #expect(entry.line == 99)
    }

    @Test func warningWithCause_includesCauseString() {
        let spy = SpyDestination()
        Log.addDestination(spy)

        struct TestError: Error, CustomStringConvertible {
            let description = "boom"
        }

        Log.warning("something failed", cause: TestError(), file: "A.swift", function: "f()", line: 1)

        let entry = spy.received.last!
        #expect(entry.level == .warning)
        #expect(entry.cause?.contains("boom") == true)
    }

    @Test func allLevels_dispatchCorrectLogLevel() {
        let spy = SpyDestination()
        Log.addDestination(spy)

        Log.debug("d", file: "F", function: "f", line: 1)
        Log.info("i", file: "F", function: "f", line: 2)
        Log.warning("w", file: "F", function: "f", line: 3)
        Log.error("e", file: "F", function: "f", line: 4)

        let levels = spy.received.map(\.level)
        #expect(levels == [.debug, .info, .warning, .error])
    }
}

private final class SpyDestination: LogDestination, Sendable {
    private let storage = Mutex<[LogEntry]>([])

    var received: [LogEntry] {
        storage.withLock { Array($0) }
    }

    func receive(_ entry: LogEntry) {
        storage.withLock { $0.append(entry) }
    }
}

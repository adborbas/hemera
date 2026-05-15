import Testing
@testable import HemeraLog

struct LogStoreTests {

    @Test func append_addsEntry() {
        let store = LogStore(capacity: 10)
        store.receive(makeEntry(message: "hello"))

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.message == "hello")
    }

    @Test func entries_returnsSnapshot() {
        let store = LogStore(capacity: 10)
        store.receive(makeEntry(message: "a"))
        store.receive(makeEntry(message: "b"))

        let snapshot = store.entries
        store.receive(makeEntry(message: "c"))

        #expect(snapshot.count == 2)
        #expect(store.entries.count == 3)
    }

    @Test func ringBuffer_evictsOldestEntries() {
        let store = LogStore(capacity: 3)
        store.receive(makeEntry(message: "1"))
        store.receive(makeEntry(message: "2"))
        store.receive(makeEntry(message: "3"))
        store.receive(makeEntry(message: "4"))

        let messages = store.entries.map(\.message)
        #expect(messages == ["2", "3", "4"])
    }

    @Test func clear_removesAllEntries() {
        let store = LogStore(capacity: 10)
        store.receive(makeEntry(message: "a"))
        store.receive(makeEntry(message: "b"))

        store.clear()

        #expect(store.entries.isEmpty)
    }

    @Test func entryFields_arePreserved() {
        let store = LogStore(capacity: 10)
        store.receive(LogEntry(
            level: .error,
            message: "something broke",
            cause: "timeout",
            file: "Foo.swift",
            function: "bar()",
            line: 42
        ))

        let entry = store.entries.first!
        #expect(entry.level == .error)
        #expect(entry.message == "something broke")
        #expect(entry.cause == "timeout")
        #expect(entry.file == "Foo.swift")
        #expect(entry.function == "bar()")
        #expect(entry.line == 42)
    }
}

private func makeEntry(message: String) -> LogEntry {
    LogEntry(level: .info, message: message, file: "Test.swift", function: "test()", line: 1)
}

import Foundation
import Synchronization

// MARK: - LogLevel

public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

// MARK: - LogEntry

public struct LogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let cause: String?
    public let file: String
    public let function: String
    public let line: Int

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        cause: String? = nil,
        file: String,
        function: String,
        line: Int
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.cause = cause
        self.file = file
        self.function = function
        self.line = line
    }
}

// MARK: - LogDestination

public protocol LogDestination: Sendable {
    func receive(_ entry: LogEntry)
}

// MARK: - Log

public enum Log {

    private static let destinations = Mutex<[any LogDestination]>([])
    private static let configured = Mutex(false)

    /// Registers the `OSLogDestination` with the given subsystem.
    /// Call once at app startup. Subsequent calls are ignored.
    public static func configure(subsystem: String) {
        let alreadyConfigured = configured.withLock { value in
            if value { return true }
            value = true
            return false
        }
        guard !alreadyConfigured else { return }
        addDestination(OSLogDestination(subsystem: subsystem))
    }

    /// Registers an additional log destination.
    public static func addDestination(_ destination: some LogDestination) {
        destinations.withLock { $0.append(destination) }
    }

    /// Removes all registered destinations. Intended for test teardown.
    public static func removeAllDestinations() {
        destinations.withLock { $0.removeAll() }
    }

    public static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        send(level: .debug, message: message, file: file, function: function, line: line)
    }

    public static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        send(level: .info, message: message, file: file, function: function, line: line)
    }

    public static func warning(
        _ message: String,
        cause: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        send(level: .warning, message: message, cause: cause, file: file, function: function, line: line)
    }

    public static func error(
        _ message: String,
        cause: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        send(level: .error, message: message, cause: cause, file: file, function: function, line: line)
    }

    // MARK: - Private

    private static func send(
        level: LogLevel,
        message: String,
        cause: Error? = nil,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        let entry = LogEntry(
            level: level,
            message: message,
            cause: cause.map { String(describing: $0) },
            file: fileName,
            function: function,
            line: line
        )

        let dests = destinations.withLock { Array($0) }
        for dest in dests {
            dest.receive(entry)
        }
    }
}

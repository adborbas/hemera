import Foundation
import os

/// Forwards log entries to Apple's unified logging system (`os.Logger`).
public struct OSLogDestination: LogDestination, Sendable {

    private let logger: Logger

    public init(subsystem: String) {
        self.logger = Logger(subsystem: subsystem, category: "general")
    }

    public func receive(_ entry: LogEntry) {
        let location = "\(entry.file):\(entry.line) \(entry.function)"
        let osLogType = osLogType(from: entry.level)

        if let cause = entry.cause {
            logger.log(level: osLogType, "[\(location, privacy: .public)] \(entry.message, privacy: .public): \(cause, privacy: .public)")
        } else {
            logger.log(level: osLogType, "[\(location, privacy: .public)] \(entry.message, privacy: .public)")
        }
    }

    private func osLogType(from level: LogLevel) -> OSLogType {
        switch level {
        case .debug: .debug
        case .info: .info
        case .warning: .default
        case .error: .error
        }
    }
}

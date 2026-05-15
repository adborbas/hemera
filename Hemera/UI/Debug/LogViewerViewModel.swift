#if DEBUG
import Foundation
import UIKit
import HemeraLog

@Observable
@MainActor
final class LogViewerViewModel {

    private(set) var entries: [LogEntry] = []
    private(set) var showCopiedToast = false
    private var dismissTask: Task<Void, Never>?

    private let store: LogStore
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    init(store: LogStore = .shared) {
        self.store = store
    }

    func load() {
        entries = store.entries.reversed()
    }

    func clear() {
        store.clear()
        entries = []
    }

    func copyToClipboard() {
        let text = entries.reversed().map { entry in
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let level = "[\(entry.level.rawValue.uppercased())]"
            let source = "\(entry.file):\(entry.line)"
            let message = entry.cause.map { "\(entry.message): \($0)" } ?? entry.message
            return "\(timestamp) \(level) \(source) \(message)"
        }.joined(separator: "\n")
        UIPasteboard.general.string = text

        dismissTask?.cancel()
        showCopiedToast = true
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showCopiedToast = false
        }
    }
}
#endif

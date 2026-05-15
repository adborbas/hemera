#if DEBUG
import SwiftUI
import HemeraLog
import Mortar

struct LogViewerView: View {

    @State private var viewModel = LogViewerViewModel()

    var body: some View {
        Group {
            if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    Localization.noLogs,
                    systemImage: "doc.text",
                    description: Text(Localization.noLogsDescription)
                )
            } else {
                List(viewModel.entries) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(Localization.logs)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.copyToClipboard()
                } label: {
                    Label(Localization.copy, systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .disabled(viewModel.entries.isEmpty)

                Button {
                    viewModel.clear()
                } label: {
                    Label(Localization.clear, systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .disabled(viewModel.entries.isEmpty)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showCopiedToast {
                HStack(spacing: Mortar.Spacing.s) {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.white)
                    Text(Localization.copiedToClipboard)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.vertical, Mortar.Spacing.m)
                .background {
                    Capsule()
                        .fill(.secondary)
                        .mortarShadow(.medium)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, Mortar.Spacing.xxl)
            }
        }
        .animation(Mortar.Motion.springNormal, value: viewModel.showCopiedToast)
        .onAppear {
            viewModel.load()
        }
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {

    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Mortar.Spacing.xxs) {
            HStack {
                Text(entry.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)

                LogLevelBadge(level: entry.level)

                Spacer()

                Text(entry.file)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(entry.cause.map { "\(entry.message): \($0)" } ?? entry.message)
                .font(.caption)
        }
        .padding(.vertical, Mortar.Spacing.xxs)
    }
}

// MARK: - Log Level Badge

private struct LogLevelBadge: View {

    let level: LogLevel

    var body: some View {
        Text(level.rawValue.uppercased())
            .font(.caption2.weight(.bold).monospaced())
            .foregroundStyle(color)
            .padding(.horizontal, Mortar.Spacing.xs)
            .padding(.vertical, Mortar.Spacing.xxs)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: Mortar.Radii.s))
    }

    private var color: Color {
        switch level {
        case .debug: .secondary
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }
}

// MARK: - Localization

private extension LogViewerView {
    enum Localization {
        static let logs = String(
            localized: "Logs",
            comment: "Navigation title for the log viewer screen (debug builds only)"
        )
        static let noLogs = String(
            localized: "No Logs",
            comment: "Title shown when the log viewer has no entries (debug builds only)"
        )
        static let copiedToClipboard = String(
            localized: "Copied to Clipboard",
            comment: "Toast message shown after copying logs to clipboard (debug builds only)"
        )
        static let noLogsDescription = String(
            localized: "Log entries will appear here as the app runs.",
            comment: "Description shown when the log viewer has no entries (debug builds only)"
        )
        static let copy = String(
            localized: "Copy",
            comment: "Toolbar button to copy logs to clipboard (debug builds only)"
        )
        static let clear = String(
            localized: "Clear",
            comment: "Toolbar button to clear all log entries (debug builds only)"
        )
    }
}
#endif

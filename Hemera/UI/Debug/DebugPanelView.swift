#if DEBUG
import SwiftUI

struct DebugPanelView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DebugPanelContentView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Label(Localization.close, systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
        }
    }
}

struct DebugPanelContentView: View {

    var body: some View {
        List {
            NavigationLink {
                LogViewerView()
            } label: {
                Label(Localization.showLogs, systemImage: "doc.text.magnifyingglass")
            }
        }
        .navigationTitle(Localization.debugPanel)
    }
}

private extension DebugPanelView {
    enum Localization {
        static let close = String(
            localized: "Close",
            comment: "Button to dismiss the debug panel"
        )
    }
}

private extension DebugPanelContentView {
    enum Localization {
        static let debugPanel = String(
            localized: "Debug Panel",
            comment: "Navigation title for the debug panel (debug builds only)"
        )
        static let showLogs = String(
            localized: "Show Logs",
            comment: "Debug panel row that navigates to the log viewer"
        )
    }
}
#endif

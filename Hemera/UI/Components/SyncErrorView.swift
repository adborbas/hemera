import SwiftUI

struct SyncErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(Localization.title, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        } description: {
            Text(Localization.description)
        } actions: {
            Button(Localization.retry) {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private extension SyncErrorView {
    enum Localization {
        static let title = String(
            localized: "Unable to Load Your Home",
            comment: "Title shown when the initial data sync with Home Assistant failed"
        )
        static let description = String(
            localized: "Make sure your Home Assistant server is running and you're on the same network, then try again.",
            comment: "Description shown when initial data sync fails, advising the user to check connectivity"
        )
        static let retry = String(
            localized: "Retry",
            comment: "Button to retry loading data after a sync failure"
        )
    }
}

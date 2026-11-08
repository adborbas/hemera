import Mortar
import SwiftUI

struct UpdateSheet: View {

    let update: AvailableUpdate
    let installedVersion: String
    let onSkip: () -> Void

    @State private var height: CGFloat = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Mortar.Spacing.xl) {
            Text(Localization.title)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: Mortar.Spacing.s) {
                VStack(spacing: Mortar.Spacing.m) {
                    LabeledContent(Localization.installed, value: installedVersion)
                    Divider()
                    LabeledContent(Localization.latest, value: update.version)
                }
                .padding(Mortar.Spacing.l)
                .background(
                    PlatformColor.secondarySystemBackground,
                    in: RoundedRectangle(cornerRadius: Mortar.Radii.s, style: .continuous)
                )

                Text(Localization.footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Mortar.Spacing.l)
            }

            VStack(spacing: Mortar.Spacing.m) {
                Button(Localization.update) {
                    openURL(URL(string: "itms-apps://apps.apple.com/app/id\(update.appStoreId)")!)
                }
                .buttonStyle(.mortarPrimary(width: .fullWidth))

                Button(Localization.skip, action: onSkip)
                    .buttonStyle(.mortarSecondary(width: .fullWidth))
            }
        }
        .padding(Mortar.Spacing.xl)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
    }
}

private extension UpdateSheet {
    enum Localization {
        static let title = String(localized: "Update Hemera", comment: "Title of the sheet offering an App Store update")
        static let installed = String(localized: "Installed", comment: "Label for the installed app version in the update sheet")
        static let latest = String(localized: "Latest", comment: "Label for the latest App Store version in the update sheet")
        static let footer = String(
            localized: "Kiosk Mode keeps Hemera on screen, so iOS can't update it automatically.",
            comment: "Explains in the update sheet why the user has to update Hemera by hand"
        )
        static let update = String(localized: "Update", comment: "Button in the update sheet that opens Hemera on the App Store")
        static let skip = String(localized: "Skip This Version", comment: "Button in the update sheet that stops the reminder for this version")
    }
}

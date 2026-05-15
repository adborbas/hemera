import SwiftUI
import Mortar

struct AcknowledgementsView: View {

    var body: some View {
        List {
            ForEach(Self.sections) { section in
                SwiftUI.Section(section.title) {
                    ForEach(section.projects) { project in
                        projectRow(project)
                    }
                }
            }
        }
        .navigationTitle(Localization.title)
    }

    private func projectRow(_ project: Project) -> some View {
        Link(destination: project.url) {
            LabeledContent {
                ExternalLinkIndicator()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .foregroundStyle(.primary)
                    Text(project.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
    }
}

// MARK: - Data

private extension AcknowledgementsView {

    struct Project: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let url: URL
    }

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let projects: [Project]
    }

    static let sections: [Section] = [
        Section(title: Localization.platform, projects: [
            Project(
                name: "Home Assistant",
                description: "Open-source home automation platform",
                url: URL(string: "https://www.home-assistant.io")!
            )
        ]),
        Section(title: Localization.libraries, projects: [
            Project(
                name: "HAKit",
                description: "Home Assistant Swift SDK",
                url: URL(string: "https://github.com/home-assistant/HAKit")!
            ),
            Project(
                name: "KeychainAccess",
                description: "Keychain services wrapper",
                url: URL(string: "https://github.com/kishikawakatsumi/KeychainAccess")!
            ),
            Project(
                name: "Starscream",
                description: "WebSocket client library",
                url: URL(string: "https://github.com/bgoncal/Starscream")!
            )
        ])
    ]
}

// MARK: - Localization

private extension AcknowledgementsView {
    enum Localization {
        static let title = String(localized: "Acknowledgements", comment: "Navigation title for the open-source acknowledgements screen")
        static let platform = String(localized: "Platform", comment: "Acknowledgements section header for the home automation platform")
        static let libraries = String(localized: "Libraries", comment: "Acknowledgements section header for third-party libraries")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
#endif

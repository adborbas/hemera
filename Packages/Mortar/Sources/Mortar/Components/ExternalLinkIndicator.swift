import SwiftUI

public struct ExternalLinkIndicator: View {

    public init() {}

    public var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

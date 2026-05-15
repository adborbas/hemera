import SwiftUI

public struct DisclosureIndicator: View {

    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.tertiary)
    }
}

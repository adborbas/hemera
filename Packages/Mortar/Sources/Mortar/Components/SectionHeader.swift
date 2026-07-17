import SwiftUI

/**
 Leading-aligned section title used to group content into labelled sections
 (e.g. floors on the Areas tab, entity categories in an area's detail).

 The component owns all of its own vertical spacing — the breathing room
 above the title (separating it from the previous section) and below it
 (separating it from its own content). Call sites must not add their own
 inter-section spacing.

 The top spacing separates the header from the previous section, so the
 first header in a list should pass `isFirst: true` to suppress it.
 */
public struct SectionHeader: View {

    private let title: String
    private let isFirst: Bool

    public init(_ title: String, isFirst: Bool = false) {
        self.title = title
        self.isFirst = isFirst
    }

    public var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isFirst ? 0 : Mortar.Spacing.xxl)
            .padding(.bottom, Mortar.Spacing.s)
    }
}

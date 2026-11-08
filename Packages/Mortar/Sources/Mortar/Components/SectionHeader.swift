import SwiftUI

/**
 Leading-aligned section title, e.g. floors on the Areas tab or categories in an area's detail.
 Sits `Spacing.l` below whatever precedes it; tile grids inset their own tiles, so nothing goes below.
*/
public struct SectionHeader: View {

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Mortar.Spacing.l)
    }
}

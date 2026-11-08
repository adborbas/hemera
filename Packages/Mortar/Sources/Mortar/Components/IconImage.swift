import SwiftUI

/// An `mdi:` icon at `size`, or an SF Symbol sized by the current font.
public struct IconImage: View {
    private let name: String
    private let size: CGFloat

    public init(_ name: String, size: CGFloat) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        if name.hasPrefix("mdi:") {
            MDIIcon(name: name, size: size)
        } else {
            Image(systemName: name)
        }
    }
}

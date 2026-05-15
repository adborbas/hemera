import Foundation

enum GridCellSpec: Equatable {
    /// Top-left logical cell of a small tile with the given title.
    case small(String)
    /// Top-left logical cell of a medium tile with the given title.
    case medium(String)
    /// Top-left logical cell of a large tile with the given title.
    case large(String)

    /// A non-top-left logical cell that is covered by the tile with the given title.
    case span(of: String)

    /// A true empty logical cell (no tile covers this position).
    case gap

    var titleIfAny: String? {
        switch self {
        case .small(let t), .medium(let t), .large(let t):
            return t
        case .span(let t):
            return t
        case .gap:
            return nil
        }
    }
}

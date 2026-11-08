import Foundation

/// A button in the header's top row, or a menu when `menu` is set.
struct FeedAction: Identifiable, Equatable {
    let id: String
    /// Also the accessibility label, since the button shows only the icon.
    let title: String
    /// SF Symbol name.
    let icon: String
    var menu: [FeedMenuItem]?
}

struct FeedMenuItem: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String?
    var isSelected: Bool
}

/// Receives taps on a feed's header actions; `item` is the menu item tapped, if any.
@MainActor
protocol FeedActionHandling: AnyObject {
    func perform(_ actionID: String, item: String?)
}

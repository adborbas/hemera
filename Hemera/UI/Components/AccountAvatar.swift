import SwiftUI

/// The account's person picture, or its initials until the picture loads or when there is none.
struct AccountAvatar: View {
    let account: Account?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: account?.pictureURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            initials
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Group {
            if let initials = account?.initials {
                Text(initials)
            } else {
                Image(systemName: "person.fill")
            }
        }
        // Three letters step down a size, as they do in Home Assistant.
        .font(.system(size: size * ((account?.initials?.count ?? 0) > 2 ? 0.3 : 0.4)))
        .foregroundStyle(badge.text.color)
        .frame(width: size, height: size)
        .background(badge.fill.color, in: .circle)
    }

    private var badge: BadgeColors { account?.badge ?? .standard }
}

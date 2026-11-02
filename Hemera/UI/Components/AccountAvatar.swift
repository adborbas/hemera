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
        .font(.system(size: size * 0.4, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(
            LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .circle
        )
    }
}

import SwiftUI

public enum ScreenshotGradient {

    public static let `default` = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.08, blue: 0.18),
            Color(red: 0.14, green: 0.06, blue: 0.24)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

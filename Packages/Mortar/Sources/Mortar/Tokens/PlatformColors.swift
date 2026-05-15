import SwiftUI

// Platform color tokens wrapping UIKit system colors.
// Guarded with #if canImport(UIKit) for macOS build compatibility.

#if canImport(UIKit)
import UIKit

public enum PlatformColor {
    public static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
    public static var systemGray: Color { Color(UIColor.systemGray) }
    public static var systemGray2: Color { Color(UIColor.systemGray2) }
    public static var systemGray3: Color { Color(UIColor.systemGray3) }
    public static var systemGray4: Color { Color(UIColor.systemGray4) }
    public static var systemGray5: Color { Color(UIColor.systemGray5) }
    public static var systemGreen: Color { Color(UIColor.systemGreen) }
}
#else
public enum PlatformColor {
    public static var secondarySystemBackground: Color { Color.gray.opacity(0.15) }
    public static var systemGray: Color { Color.gray }
    public static var systemGray2: Color { Color.gray.opacity(0.7) }
    public static var systemGray3: Color { Color.gray.opacity(0.5) }
    public static var systemGray4: Color { Color.gray.opacity(0.35) }
    public static var systemGray5: Color { Color.gray.opacity(0.2) }
    public static var systemGreen: Color { Color.green }
}
#endif

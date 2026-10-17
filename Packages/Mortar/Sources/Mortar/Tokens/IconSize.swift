import Foundation

extension Mortar {
    public enum IconSize {
        /**
         Inline badge sitting alongside `.subheadline` text.

         Larger than that style's 15pt because an MDI glyph fills its em box exactly, where the SF
         Symbol this replaced drew well outside its own point size. Scales with Dynamic Type at the
         call site — it tracks a type style, not a container.
        */
        public static let xs: CGFloat = 19
        public static let s: CGFloat = 28
        public static let m: CGFloat = 48
    }
}

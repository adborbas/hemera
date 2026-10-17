import Foundation

extension Mortar {
    public enum IconSize {
        /**
         Inline badge size, matching `.subheadline` metrics so a glyph sits level with body text.

         Not derived from the `s`/`m` steps: it tracks a type style rather than a container, which is
         why it is an odd number.
        */
        public static let xs: CGFloat = 15
        public static let s: CGFloat = 28
        public static let m: CGFloat = 48
    }
}

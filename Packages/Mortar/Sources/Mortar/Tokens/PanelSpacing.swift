import Foundation

extension Mortar {
    /// Spacing tokens for full-screen panels and overlays.
    ///
    /// These values are larger than `Mortar.Spacing` (which maxes at 24)
    /// and are used for generous padding in control panels, onboarding,
    /// and modal sheets.
    public enum PanelSpacing {
        /// Vertical breathing room around content areas.
        public static let content: CGFloat = 32
        /// Outer edge/margin spacing in full-screen views.
        public static let edge: CGFloat = 40
        /// Top spacing above panel headers and titles.
        public static let header: CGFloat = 48
        /// Generous bottom padding (safe area + breathing room).
        public static let footer: CGFloat = 64
    }
}

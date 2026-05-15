import SwiftUI

extension Mortar {
    public enum Motion {
        public static let fast: Double = 0.15
        public static let normal: Double = 0.2
        public static let slow: Double = 0.3

        /// Per-tile delay for staggered cascade animations.
        public static let staggerInterval: Double = 0.04

        public static var springFast: Animation { .spring(duration: fast) }
        public static var springNormal: Animation { .spring(duration: normal) }
        public static var springBouncy: Animation { .spring(duration: slow, bounce: 0.15) }
        /// Entrance-quality spring — slightly longer than springBouncy for visual settling.
        public static var springSnappy: Animation { .spring(duration: 0.35, bounce: 0.12) }
    }
}

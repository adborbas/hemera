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

        /// Light spilling out of a card's icon as its entity becomes active.
        public static var glowExpand: Animation { .easeOut(duration: 0.45) }
        /// The same glow drawn back into the icon — accelerating inwards as it shrinks.
        public static var glowCollapse: Animation { .easeIn(duration: glowCollapseDuration) }
        public static let glowCollapseDuration: Double = slow
        /// When the glow looks gone: before the curve ends, as its last scale hides behind the icon.
        public static let glowRetreatDuration: Double = glowCollapseDuration * 0.8
    }
}

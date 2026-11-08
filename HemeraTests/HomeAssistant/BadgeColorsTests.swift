import Testing
@testable import Hemera

/** Expected values come from running Home Assistant's frontend colour code on the same primaries,
 so the avatar matches the one in its web app. */
@MainActor
struct BadgeColorsTests {

    private func rgb(_ hex: Int) -> BadgeColors.RGB {
        BadgeColors.RGB(red: hex >> 16 & 0xFF, green: hex >> 8 & 0xFF, blue: hex & 0xFF)
    }

    @Test func primaryColor_light_brightensWithDarkText() {
        let badge = BadgeColors(primaryColor: "#fc8163")

        #expect(badge.fill == rgb(0xFFB291))
        #expect(badge.text == rgb(0x212121))
    }

    @Test func primaryColor_dark_brightensWithWhiteText() {
        #expect(BadgeColors(primaryColor: "#000000") == BadgeColors(fill: rgb(0x2C2C2C), text: rgb(0xFFFFFF)))
    }

    @Test func primaryColor_brightenedPastWhite_isClampedButJudgedUnclamped() {
        // Contrast is measured before clamping; the clamped colour would pick dark text.
        #expect(BadgeColors(primaryColor: "#6200ee") == BadgeColors(fill: rgb(0x9E47FF), text: rgb(0xFFFFFF)))
    }

    @Test func primaryColor_noneOrUnreadable_usesHomeAssistantsDefault() {
        #expect(BadgeColors(primaryColor: nil) == .standard)
        #expect(BadgeColors(primaryColor: "salmon") == .standard)
        #expect(BadgeColors.standard == BadgeColors(fill: rgb(0xB3E5FC), text: rgb(0x212121)))
    }
}

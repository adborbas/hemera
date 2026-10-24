import Testing
@testable import Hemera

struct LitAppearanceTests {

    // MARK: - Holding

    /// The glow needs a moment to retract, and the card has to stay lit for exactly that long.
    @Test
    func observe_turningOff_holdsTheLitLook() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: true, glowing: true)

        let held = appearance.observe(isOn: false, glowing: true)

        #expect(held)
        #expect(appearance.isLit(whenOn: false))
    }

    @Test
    func endHold_stopsReadingAsLit() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: true, glowing: true)
        _ = appearance.observe(isOn: false, glowing: true)

        appearance.endHold()

        #expect(!appearance.isLit(whenOn: false))
    }

    // MARK: - Not Holding

    /**
     The card's task runs on every appearance, not only on a change. Holding for an off light that
     was simply drawn again would light a card whose lamp is off.
    */
    @Test
    func observe_seeingTheSameOffStateAgain_doesNotHold() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: false, glowing: true)

        let held = appearance.observe(isOn: false, glowing: true)

        #expect(!held)
        #expect(!appearance.isLit(whenOn: false))
    }

    /// A card appearing on a light that is already off has no transition to cover.
    @Test
    func observe_firstSightOfAnOffLight_doesNotHold() {
        var appearance = LitAppearance()

        let held = appearance.observe(isOn: false, glowing: true)

        #expect(!held)
        #expect(!appearance.isLit(whenOn: false))
    }

    /// Turning on is the lamp's own job to show; only the retraction needs covering.
    @Test
    func observe_turningOn_doesNotHold() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: false, glowing: true)

        let held = appearance.observe(isOn: true, glowing: true)

        #expect(!held)
    }

    /// With Reduce Motion there is no glow to outlast, so the card must go dark immediately.
    @Test
    func observe_turningOffWithoutGlow_doesNotHold() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: true, glowing: false)

        let held = appearance.observe(isOn: false, glowing: false)

        #expect(!held)
        #expect(!appearance.isLit(whenOn: false))
    }

    /// A hold must not outlive the transition that started it, however the card is used next.
    @Test
    func observe_afterAHold_clearsIt() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: true, glowing: true)
        _ = appearance.observe(isOn: false, glowing: true)
        #expect(appearance.isLit(whenOn: false))

        _ = appearance.observe(isOn: false, glowing: true)

        #expect(!appearance.isLit(whenOn: false))
    }

    // MARK: - Reading

    @Test
    func isLit_whileOn_isAlwaysTrue() {
        var appearance = LitAppearance()
        _ = appearance.observe(isOn: true, glowing: true)

        #expect(appearance.isLit(whenOn: true))
    }
}

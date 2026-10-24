import Foundation

/**
 Whether a light card should read as lit, which is not the same question as whether the light is on.

 The glow takes a moment to retract into the icon, and a bulb going dark while the card is still
 washed shows both states at once. So an on → off transition holds the lit look until the glow is
 home. Only a transition may hold: the card's task also runs when the view merely reappears, and
 re-lighting an off card then is the bug this type exists to make unrepresentable.
*/
struct LitAppearance {

    /// Nil until the first observation, so a card appearing on an off light never holds.
    private var previousIsOn: Bool?
    private var isHolding = false

    /// Whether the card should be drawn lit, given what the entity currently reports.
    func isLit(whenOn isOn: Bool) -> Bool {
        isOn || isHolding
    }

    /**
     Takes the entity's current state and answers whether the caller must now wait out the glow
     before calling `endHold()`. Anything that is not a transition to off clears the hold, so a
     stale one cannot survive a reappearance.

     - Parameter glowing: false when the glow is suppressed (Reduce Motion) and there is therefore
       nothing to wait for.
    */
    mutating func observe(isOn: Bool, glowing: Bool) -> Bool {
        let turnedOff = previousIsOn == true && !isOn && glowing
        previousIsOn = isOn
        isHolding = turnedOff
        return turnedOff
    }

    /// Ends the hold, whether the wait finished or was cut short by the view going away.
    mutating func endHold() {
        isHolding = false
    }
}

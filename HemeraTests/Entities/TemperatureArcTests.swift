import CoreGraphics
import Foundation
import Testing
@testable import Hemera

/// A wrong mapping here silently sets the wrong temperature on someone's heating.
@MainActor
struct TemperatureArcTests {

    private let arc = TemperatureArc(range: 7...35, step: 0.5)

    // MARK: - Angle Mapping

    @Test func angleForTemperature_boundsMapToArcEnds() {
        #expect(arc.angle(forTemperature: 7) == TemperatureArc.startAngle)
        #expect(arc.angle(forTemperature: 35) == TemperatureArc.startAngle + TemperatureArc.sweepAngle)
    }

    @Test func angleForTemperature_midpointIsHalfwayAlongTheSweep() {
        #expect(arc.angle(forTemperature: 21) == TemperatureArc.startAngle + TemperatureArc.sweepAngle / 2)
    }

    /// Plenty of integrations report a target outside their own min/max.
    @Test func angleForTemperature_outOfRange_clampsToTheEnds() {
        #expect(arc.angle(forTemperature: -40) == TemperatureArc.startAngle)
        #expect(arc.angle(forTemperature: 400) == TemperatureArc.startAngle + TemperatureArc.sweepAngle)
    }

    /// Without this the handle drifts away from the finger.
    @Test func temperatureForAngle_roundTripsWithAngleForTemperature() {
        for temperature in [7.0, 12.5, 21.0, 30.0, 35.0] {
            let roundTripped = arc.temperature(forAngle: arc.angle(forTemperature: temperature))
            #expect(abs(roundTripped - temperature) < 0.0001)
        }
    }

    /// Unnormalised, the hottest quarter of the dial reads as the coldest.
    @Test func temperatureForAngle_pastTheWrapPoint_staysAtTheHotEnd() {
        // 405° is the arc's end; it arrives from `atan2` as 45°.
        #expect(arc.temperature(forAngle: 45) == 35)
        #expect(arc.temperature(forAngle: 0) == arc.temperature(forAngle: 360))
    }

    // MARK: - Arc Gap

    /// A drag across the open wedge must not jump the handle extreme to extreme.
    @Test func isOnArc_rejectsOnlyTheBottomWedge() {
        #expect(TemperatureArc.isOnArc(90) == false)
        #expect(TemperatureArc.isOnArc(46) == false)
        #expect(TemperatureArc.isOnArc(134) == false)

        #expect(TemperatureArc.isOnArc(135) == true)
        #expect(TemperatureArc.isOnArc(45) == true)
        #expect(TemperatureArc.isOnArc(0) == true)
        #expect(TemperatureArc.isOnArc(270) == true)
    }

    @Test func angleFromPoint_measuresClockwiseFromTheRight() {
        let center = CGPoint(x: 100, y: 100)

        #expect(TemperatureArc.angle(from: CGPoint(x: 200, y: 100), center: center) == 0)
        // Screen y grows downwards, so 90° is below the centre.
        #expect(TemperatureArc.angle(from: CGPoint(x: 100, y: 200), center: center) == 90)
        #expect(TemperatureArc.angle(from: CGPoint(x: 100, y: 0), center: center) == 270)
    }

    @Test func point_andAngle_areInverses() {
        let center = CGPoint(x: 50, y: 50)
        let point = TemperatureArc.point(center: center, radius: 20, angleDegrees: 135)

        #expect(abs(TemperatureArc.angle(from: point, center: center) - 135) < 0.0001)
    }

    // MARK: - Snapping

    @Test func snap_roundsToTheNearestStep() {
        #expect(arc.snap(21.2) == 21.0)
        #expect(arc.snap(21.4) == 21.5)
    }

    @Test func snap_clampsIntoRange() {
        #expect(arc.snap(-10) == 7)
        #expect(arc.snap(99) == 35)
    }

    /// `max_temp` need not sit on the step grid; rounding must not carry it past the bound.
    @Test func snap_withBoundsOffTheStepGrid_staysInRange() {
        let offGrid = TemperatureArc(range: 7.4...93.6, step: 1)

        #expect(offGrid.snap(93.6) == 93.6)
        #expect(offGrid.snap(200) == 93.6)
        #expect(offGrid.snap(7.4) == 7.4)
        #expect(offGrid.snap(-10) == 7.4)
    }

    /// Regression: `target_temp_step: 0` reached the divisor, sending `NaN` to Home Assistant.
    @Test func snap_withZeroStep_fallsBackInsteadOfProducingNaN() {
        let zeroStep = TemperatureArc(range: 7...35, step: 0)

        let snapped = zeroStep.snap(21.2)

        #expect(!snapped.isNaN)
        #expect(snapped == 21.0)
    }

    @Test func snap_withNegativeStep_fallsBack() {
        #expect(TemperatureArc(range: 7...35, step: -1).snap(21.4) == 21.5)
    }

    // MARK: - Handle Separation

    /// Regression: a hardcoded 1° gap refused setpoints a half-degree device accepts.
    @Test func lowSetpoint_keepsOneStepBelowHigh_notOneDegree() {
        #expect(arc.lowSetpoint(24, below: 22) == 21.5)
    }

    @Test func highSetpoint_keepsOneStepAboveLow_notOneDegree() {
        #expect(arc.highSetpoint(16, above: 22) == 22.5)
    }

    @Test func lowSetpoint_withWholeDegreeStep_keepsAFullDegree() {
        let wholeDegrees = TemperatureArc(range: 7...35, step: 1)

        #expect(wholeDegrees.lowSetpoint(24, below: 22) == 21)
        #expect(wholeDegrees.highSetpoint(16, above: 22) == 23)
    }

    @Test func setpoints_whenClearOfTheOtherHandle_justSnap() {
        #expect(arc.lowSetpoint(18.2, below: 24) == 18.0)
        #expect(arc.highSetpoint(26.4, above: 20) == 26.5)
    }

    /// With the other handle on a bound, the one-step gap would leave the range.
    @Test func setpoints_withTheOtherHandleOnABound_stayInRange() {
        #expect(arc.lowSetpoint(20, below: 7) == 7)
        #expect(arc.highSetpoint(20, above: 35) == 35)
    }
}

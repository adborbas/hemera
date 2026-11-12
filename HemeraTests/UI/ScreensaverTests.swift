import CoreGraphics
import Testing
@testable import Hemera

@MainActor
struct ScreensaverTests {

    @Test func clockOffset_whenShown_isCentred() {
        #expect(Screensaver.clockOffset(minutesShown: 0) == .zero)
    }

    @Test func clockOffset_overADay_staysWithinTwelvePoints() {
        for minute in 0...(24 * 60) {
            let offset = Screensaver.clockOffset(minutesShown: minute)
            #expect(abs(offset.width) <= 12 && abs(offset.height) <= 12, "minute \(minute): \(offset)")
        }
    }

    // A minute where the clock doesn't move would leave the same pixels lit for another minute.
    @Test func clockOffset_overTheFirstHour_movesEveryMinute() {
        for minute in 0..<60 {
            #expect(Screensaver.clockOffset(minutesShown: minute) != Screensaver.clockOffset(minutesShown: minute + 1))
        }
    }
}

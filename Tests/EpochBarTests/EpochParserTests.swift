import Testing
import Foundation
@testable import EpochBar

@Suite struct EpochParserTests {
    @Test func parsesTenDigitSeconds() {
        // 1735689600 = 2025-01-01T00:00:00Z
        let parsed = EpochParser.parse("1735689600")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == false)
        #expect(abs((parsed?.date.timeIntervalSince1970 ?? 0) - 1735689600) < 0.0001)
    }

    @Test func parsesFractionalSeconds() {
        // 1735689600.5 = 2025-01-01T00:00:00.500Z
        let parsed = EpochParser.parse("1735689600.5")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(abs((parsed?.date.timeIntervalSince1970 ?? 0) - 1735689600.5) < 0.0001)
    }

    @Test func parsesThirteenDigitMilliseconds() {
        // 1735689600500 ms = 2025-01-01T00:00:00.500Z
        let parsed = EpochParser.parse("1735689600500")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(abs((parsed?.date.timeIntervalSince1970 ?? 0) - 1735689600.5) < 0.0001)
    }

    @Test func parsesSixteenDigitMicroseconds() {
        // 1735689600500000 µs = 2025-01-01T00:00:00.500Z
        let parsed = EpochParser.parse("1735689600500000")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(abs((parsed?.date.timeIntervalSince1970 ?? 0) - 1735689600.5) < 0.0001)
    }

    @Test func formatSecondPrecision() {
        let parsed = EpochParser.parse("1735689600")!
        #expect(EpochParser.formatISO(parsed) == "2025-01-01T00:00:00Z")
    }

    @Test func formatMillisecondPrecisionFromFractional() {
        let parsed = EpochParser.parse("1735689600.5")!
        #expect(EpochParser.formatISO(parsed) == "2025-01-01T00:00:00.500Z")
    }

    @Test func formatMillisecondPrecisionFromMs() {
        let parsed = EpochParser.parse("1735689600500")!
        #expect(EpochParser.formatISO(parsed) == "2025-01-01T00:00:00.500Z")
    }

    @Test func formatMillisecondPrecisionFromMicroseconds() {
        let parsed = EpochParser.parse("1735689600500000")!
        #expect(EpochParser.formatISO(parsed) == "2025-01-01T00:00:00.500Z")
    }

    @Test func formatTruncatesDoesNotRound() {
        // 1735689600.999999 must format as .999, not round up to next second
        let parsed = EpochParser.parse("1735689600.999999")!
        #expect(EpochParser.formatISO(parsed) == "2025-01-01T00:00:00.999Z")
    }
}

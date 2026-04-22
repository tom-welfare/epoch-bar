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

    @Test func rejectsNonNumeric() {
        #expect(EpochParser.parse("abc") == nil)
        #expect(EpochParser.parse("1234abc") == nil)
        #expect(EpochParser.parse("") == nil)
    }

    @Test func rejectsUnsupportedDigitLengths() {
        #expect(EpochParser.parse("12345") == nil)            // 5 digits
        #expect(EpochParser.parse("17356896001") == nil)      // 11 digits
        #expect(EpochParser.parse("173568960050") == nil)     // 12 digits
        #expect(EpochParser.parse("17356896005000") == nil)   // 14 digits
        #expect(EpochParser.parse("173568960050000") == nil)  // 15 digits
    }

    @Test func rejectsOutOfRangeLow() {
        // epoch 0 = 1970-01-01, below 2001-01-01 cutoff
        #expect(EpochParser.parse("0000000000") == nil)
    }

    @Test func rejectsOutOfRangeHigh() {
        // 9999999999 = 2286-11-20, above 2099-12-31 cutoff
        #expect(EpochParser.parse("9999999999") == nil)
    }

    @Test func trimsWhitespace() {
        #expect(EpochParser.parse("  1735689600\n") != nil)
        #expect(EpochParser.parse("\t1735689600  ") != nil)
    }

    @Test func parsesMongoObjectId() {
        // 507f1f77bcf86cd799439011: first 4 bytes = 0x507f1f77 = 1351038839 = 2012-10-17T21:13:27Z
        let parsed = EpochParser.parse("507f1f77bcf86cd799439011")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == false)
        #expect(EpochParser.formatISO(parsed!) == "2012-10-17T21:13:27Z")
    }

    @Test func parsesUppercaseMongoObjectId() {
        let parsed = EpochParser.parse("507F1F77BCF86CD799439011")
        #expect(EpochParser.formatISO(parsed!) == "2012-10-17T21:13:27Z")
    }

    @Test func rejectsMongoObjectIdWithOutOfRangeTimestamp() {
        // 00000000... would give epoch 0 = 1970, below 2001-01-01 cutoff
        #expect(EpochParser.parse("000000000000000000000000") == nil)
    }

    @Test func rejectsNonHex24CharStrings() {
        // 24 chars but contains non-hex character
        #expect(EpochParser.parse("507f1f77bcf86cd79943901g") == nil)
    }
}

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

    // MARK: - ULID

    @Test func parsesULID() {
        // Canonical ULID spec example; timestamp portion "01ARZ3NDEK" = 1469918176159 ms
        let parsed = EpochParser.parse("01ARZ3NDEKTSV4RRFFQ69G5FAV")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(EpochParser.formatISO(parsed!) == "2016-07-30T23:54:10.259Z")
    }

    @Test func parsesLowercaseULID() {
        let parsed = EpochParser.parse("01arz3ndektsv4rrffq69g5fav")
        #expect(EpochParser.formatISO(parsed!) == "2016-07-30T23:54:10.259Z")
    }

    @Test func rejectsULIDWithInvalidCharacter() {
        // Contains 'I' which is not in the Crockford alphabet
        #expect(EpochParser.parse("01ARZ3NDEKTSV4RRFFQ69G5FAI") == nil)
    }

    // MARK: - UUID

    @Test func parsesUUIDv1() {
        // From https://www.uuidtools.com/generate/v1 example
        let parsed = EpochParser.parse("e4eaaaf2-d142-11e1-b3e4-080027620cdd")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(EpochParser.formatISO(parsed!) == "2012-07-19T01:41:43.645Z")
    }

    @Test func parsesUUIDv6() {
        // The UUIDv6 re-ordering of the v1 above should decode to the same instant
        let parsed = EpochParser.parse("1e1d142e-4eaa-6af2-b3e4-080027620cdd")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(EpochParser.formatISO(parsed!) == "2012-07-19T01:41:43.645Z")
    }

    @Test func parsesUUIDv7() {
        // First 48 bits = unix ms. 0x018d4fa34f8e = 1703800815502 ms
        let parsed = EpochParser.parse("018d4fa3-4f8e-7890-abcd-ef0123456789")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(EpochParser.formatISO(parsed!) == "2024-01-28T10:35:19.310Z")
    }

    @Test func rejectsUUIDv4WithoutTimestamp() {
        // Version 4 is random, not timestamped
        #expect(EpochParser.parse("550e8400-e29b-41d4-a716-446655440000") == nil)
    }

    @Test func rejectsUUIDWithoutHyphens() {
        // Canonical form only
        #expect(EpochParser.parse("e4eaaaf2d14211e1b3e4080027620cdd") == nil)
    }

    // MARK: - Snowflake

    @Test func parsesTwitterSnowflake() {
        // (1800000000000000000 >> 22) + Twitter epoch = 1718015762... ≈ 2024-06-10
        let parsed = EpochParser.parse("1800000000000000000")
        #expect(parsed != nil)
        #expect(parsed?.hasSubSecond == true)
        #expect(EpochParser.formatISO(parsed!) == "2024-06-10T03:00:17.039Z")
    }

    @Test func rejectsSixteenDigitValueAsSnowflake() {
        // 16 digits is still microseconds, not a snowflake
        let parsed = EpochParser.parse("1735689600000000")
        #expect(parsed?.hasSubSecond == true)
        // Must be interpreted as µs: 2025-01-01
        #expect(EpochParser.formatISO(parsed!) == "2025-01-01T00:00:00.000Z")
    }
}

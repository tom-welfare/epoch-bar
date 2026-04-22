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
}

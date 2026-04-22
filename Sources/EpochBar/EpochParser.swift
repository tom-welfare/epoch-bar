import Foundation

struct ParsedEpoch: Equatable, Sendable {
    let date: Date
    let hasSubSecond: Bool
}

enum EpochParser {
    private static let minDate = Date(timeIntervalSince1970: 978_307_200)    // 2001-01-01 00:00:00 UTC
    private static let maxDate = Date(timeIntervalSince1970: 4_102_444_799)  // 2099-12-31 23:59:59 UTC

    /// Seconds between 1582-10-15 (Gregorian reform, UUIDv1/v6 epoch) and 1970-01-01.
    private static let uuidEpochOffsetSec: TimeInterval = 12_219_292_800

    /// Twitter snowflake epoch: 2010-11-04T01:42:54.657 UTC, in Unix ms.
    private static let twitterEpochMs: UInt64 = 1_288_834_974_657

    private static let ulidAlphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func parse(_ raw: String) -> ParsedEpoch? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let parsed = parseDecimal(trimmed)
            ?? parseMongoObjectId(trimmed)
            ?? parseULID(trimmed)
            ?? parseUUID(trimmed)
            ?? parseSnowflake(trimmed)

        guard let p = parsed, p.date >= minDate, p.date <= maxDate else { return nil }
        return p
    }

    private static func parseDecimal(_ s: String) -> ParsedEpoch? {
        if s.range(of: #"^\d{10}$"#, options: .regularExpression) != nil,
           let seconds = Double(s) {
            return ParsedEpoch(date: Date(timeIntervalSince1970: seconds), hasSubSecond: false)
        }
        if s.range(of: #"^\d{10}\.\d+$"#, options: .regularExpression) != nil,
           let seconds = Double(s) {
            return ParsedEpoch(date: Date(timeIntervalSince1970: seconds), hasSubSecond: true)
        }
        if s.range(of: #"^\d{13}$"#, options: .regularExpression) != nil,
           let ms = Double(s) {
            return ParsedEpoch(date: Date(timeIntervalSince1970: ms / 1000), hasSubSecond: true)
        }
        if s.range(of: #"^\d{16}$"#, options: .regularExpression) != nil,
           let us = Double(s) {
            return ParsedEpoch(date: Date(timeIntervalSince1970: us / 1_000_000), hasSubSecond: true)
        }
        return nil
    }

    private static func parseMongoObjectId(_ s: String) -> ParsedEpoch? {
        guard s.range(of: #"^[0-9a-fA-F]{24}$"#, options: .regularExpression) != nil,
              let seconds = UInt32(s.prefix(8), radix: 16) else {
            return nil
        }
        return ParsedEpoch(date: Date(timeIntervalSince1970: TimeInterval(seconds)), hasSubSecond: false)
    }

    private static func parseULID(_ s: String) -> ParsedEpoch? {
        let upper = s.uppercased()
        guard upper.range(of: #"^[0-9A-HJKMNP-TV-Z]{26}$"#, options: .regularExpression) != nil else {
            return nil
        }
        var ms: UInt64 = 0
        for ch in upper.prefix(10) {
            guard let digit = ulidAlphabet.firstIndex(of: ch) else { return nil }
            ms = (ms << 5) | UInt64(digit)
        }
        return ParsedEpoch(date: Date(timeIntervalSince1970: TimeInterval(ms) / 1000), hasSubSecond: true)
    }

    private static func parseUUID(_ s: String) -> ParsedEpoch? {
        // Canonical hyphenated UUID form with version nibble 1-7 at position 14.
        guard s.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-7][0-9a-fA-F]{3}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#,
                      options: .regularExpression) != nil else {
            return nil
        }
        let hex = s.replacingOccurrences(of: "-", with: "")
        let versionChar = hex[hex.index(hex.startIndex, offsetBy: 12)]
        guard let version = Int(String(versionChar), radix: 16) else { return nil }

        switch version {
        case 1: return decodeUUIDv1(hex: hex)
        case 6: return decodeUUIDv6(hex: hex)
        case 7: return decodeUUIDv7(hex: hex)
        default: return nil   // v2-v5 don't carry a timestamp
        }
    }

    private static func decodeUUIDv1(hex: String) -> ParsedEpoch? {
        // timestamp_100ns = (time_hi_low_12 << 48) | (time_mid << 32) | time_low
        let timeLowStr = String(hex.prefix(8))
        let timeMidStr = String(hex.dropFirst(8).prefix(4))
        let timeHiStr  = String(hex.dropFirst(13).prefix(3))   // skip version nibble
        guard let timeLow = UInt64(timeLowStr, radix: 16),
              let timeMid = UInt64(timeMidStr, radix: 16),
              let timeHi  = UInt64(timeHiStr,  radix: 16) else {
            return nil
        }
        let ts100ns = (timeHi << 48) | (timeMid << 32) | timeLow
        return uuidGregorianToEpoch(ts100ns)
    }

    private static func decodeUUIDv6(hex: String) -> ParsedEpoch? {
        // timestamp_100ns = (time_high << 28) | (time_mid << 12) | time_low_12
        let timeHighStr = String(hex.prefix(8))
        let timeMidStr  = String(hex.dropFirst(8).prefix(4))
        let timeLowStr  = String(hex.dropFirst(13).prefix(3))   // skip version nibble
        guard let timeHigh = UInt64(timeHighStr, radix: 16),
              let timeMid  = UInt64(timeMidStr,  radix: 16),
              let timeLow  = UInt64(timeLowStr,  radix: 16) else {
            return nil
        }
        let ts100ns = (timeHigh << 28) | (timeMid << 12) | timeLow
        return uuidGregorianToEpoch(ts100ns)
    }

    private static func decodeUUIDv7(hex: String) -> ParsedEpoch? {
        // First 48 bits = Unix ms.
        let msStr = String(hex.prefix(12))
        guard let ms = UInt64(msStr, radix: 16) else { return nil }
        return ParsedEpoch(date: Date(timeIntervalSince1970: TimeInterval(ms) / 1000), hasSubSecond: true)
    }

    private static func uuidGregorianToEpoch(_ ts100ns: UInt64) -> ParsedEpoch {
        let unixSecs = (TimeInterval(ts100ns) / 10_000_000) - uuidEpochOffsetSec
        return ParsedEpoch(date: Date(timeIntervalSince1970: unixSecs), hasSubSecond: true)
    }

    private static func parseSnowflake(_ s: String) -> ParsedEpoch? {
        // 17-19 decimal digits, Twitter epoch. 16 digits stays as microseconds (handled above).
        guard s.range(of: #"^\d{17,19}$"#, options: .regularExpression) != nil,
              let value = UInt64(s) else {
            return nil
        }
        let unixMs = (value >> 22) + twitterEpochMs
        return ParsedEpoch(date: Date(timeIntervalSince1970: TimeInterval(unixMs) / 1000), hasSubSecond: true)
    }

    static func formatISO(_ parsed: ParsedEpoch) -> String {
        var date = parsed.date
        if parsed.hasSubSecond {
            // Truncate (toward zero) to millisecond precision
            let secs = date.timeIntervalSince1970
            let truncatedMs = (secs * 1000).rounded(.down) / 1000
            date = Date(timeIntervalSince1970: truncatedMs)
        }

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        if parsed.hasSubSecond {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        } else {
            formatter.formatOptions = [.withInternetDateTime]
        }
        return formatter.string(from: date)
    }
}

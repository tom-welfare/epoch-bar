import Foundation

struct ParsedEpoch: Equatable, Sendable {
    let date: Date
    let hasSubSecond: Bool
}

enum EpochParser {
    private static let minDate = Date(timeIntervalSince1970: 978_307_200)    // 2001-01-01 00:00:00 UTC
    private static let maxDate = Date(timeIntervalSince1970: 4_102_444_799)  // 2099-12-31 23:59:59 UTC

    static func parse(_ raw: String) -> ParsedEpoch? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: ParsedEpoch?

        if trimmed.range(of: #"^\d{10}$"#, options: .regularExpression) != nil,
           let seconds = Double(trimmed) {
            parsed = ParsedEpoch(date: Date(timeIntervalSince1970: seconds), hasSubSecond: false)
        } else if trimmed.range(of: #"^\d{10}\.\d+$"#, options: .regularExpression) != nil,
                  let seconds = Double(trimmed) {
            parsed = ParsedEpoch(date: Date(timeIntervalSince1970: seconds), hasSubSecond: true)
        } else if trimmed.range(of: #"^\d{13}$"#, options: .regularExpression) != nil,
                  let ms = Double(trimmed) {
            parsed = ParsedEpoch(date: Date(timeIntervalSince1970: ms / 1000), hasSubSecond: true)
        } else if trimmed.range(of: #"^\d{16}$"#, options: .regularExpression) != nil,
                  let us = Double(trimmed) {
            parsed = ParsedEpoch(date: Date(timeIntervalSince1970: us / 1_000_000), hasSubSecond: true)
        } else if trimmed.range(of: #"^[0-9a-fA-F]{24}$"#, options: .regularExpression) != nil,
                  let seconds = UInt32(trimmed.prefix(8), radix: 16) {
            parsed = ParsedEpoch(date: Date(timeIntervalSince1970: TimeInterval(seconds)), hasSubSecond: false)
        } else {
            parsed = nil
        }

        guard let p = parsed, p.date >= minDate, p.date <= maxDate else { return nil }
        return p
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

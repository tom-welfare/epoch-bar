import Foundation

struct ParsedEpoch: Equatable {
    let date: Date
    let hasSubSecond: Bool
}

enum EpochParser {
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
        } else {
            parsed = nil
        }

        return parsed
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

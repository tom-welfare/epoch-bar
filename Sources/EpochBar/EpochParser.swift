import Foundation

struct ParsedEpoch: Equatable {
    let date: Date
    let hasSubSecond: Bool
}

enum EpochParser {
    static func parse(_ raw: String) -> ParsedEpoch? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^\d{10}$"#, options: .regularExpression) != nil,
              let seconds = Double(trimmed) else {
            return nil
        }
        return ParsedEpoch(date: Date(timeIntervalSince1970: seconds), hasSubSecond: false)
    }
}

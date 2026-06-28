import Foundation

extension JSONDecoder {
    /// A decoder configured for AccessLink payloads. Field mapping stays explicit
    /// via each model's `CodingKeys` (no global `.convertFromSnakeCase`, so the
    /// wire contract is auditable — Norm 3). Dates are parsed tolerantly across the
    /// **five** formats Polar emits (verified against live captures, 2026-06-28):
    /// zoned-offset, zoned-`Z`, naive-seconds, naive-minute, and date-only.
    ///
    /// A fresh decoder is built per fetch call; `JSONDecoder` is a reference type
    /// and is not shared across concurrent decodes (Safeguard 7).
    static func polar() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { inner in
            let string = try inner.singleValueContainer().decode(String.self)
            if let date = PolarDateParser.shared.date(from: string) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: inner.codingPath, debugDescription: "Unparseable Polar date: \(string)")
            )
        }
        return decoder
    }
}

/// Tolerant multi-format date parsing. The formatters are configured once and
/// only ever *read* (never mutated), which `DateFormatter` documents as safe for
/// concurrent parsing — hence `@unchecked Sendable`. Zoned patterns honor the
/// in-string offset; naive patterns are interpreted as UTC for stable bucketing.
struct PolarDateParser: @unchecked Sendable {
    static let shared = PolarDateParser()

    private let formatters: [DateFormatter]

    private init() {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ", // zoned + millis: 2026-06-17T12:52:51.000Z
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",     // zoned:         ...:51Z / ...+05:30
            "yyyy-MM-dd'T'HH:mm:ss",          // naive seconds: 2026-05-29T18:07:39
            "yyyy-MM-dd'T'HH:mm",             // naive minute:  2026-06-21T00:00
            "yyyy-MM-dd",                     // date only:     2026-06-21
        ]
        formatters = patterns.map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.calendar = Calendar(identifier: .gregorian)
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = pattern
            return f
        }
    }

    func date(from string: String) -> Date? {
        for f in formatters {
            if let date = f.date(from: string) { return date }
        }
        return nil
    }
}

/// Minimal ISO-8601 *duration* parser (`PnDTnHnMnS`) → seconds. v3 activity
/// returns `active_duration` / `inactive_duration` in this form (e.g. `PT1H30M`).
enum ISO8601Duration {
    static func seconds(from string: String) -> TimeInterval? {
        guard string.hasPrefix("P") else { return nil }
        var total: TimeInterval = 0
        var number = ""
        var inTime = false

        for ch in string.dropFirst() {
            switch ch {
            case "T":
                inTime = true
            case "0"..."9", ".":
                number.append(ch)
            default:
                guard let value = Double(number) else { return total == 0 ? nil : total }
                switch ch {
                case "D": total += value * 86_400
                case "H": total += value * 3_600
                case "M": total += value * (inTime ? 60 : 0) // calendar months unsupported → ignore
                case "S": total += value
                default: break
                }
                number = ""
            }
        }
        return total
    }
}

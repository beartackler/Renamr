import Foundation

/// A clock time. We reformat its LAYOUT (separators, seconds, meridiem, padding)
/// but never do 12↔24 conversion — that arithmetic isn't inferable from one example.
public struct TimeValue: Equatable, Sendable {
    public let hour: Int
    public let minute: Int
    public let second: Int?
    public let meridiem: String?   // "AM" / "PM" / nil

    var isValid: Bool {
        let h = meridiem != nil ? (hour >= 1 && hour <= 12) : (hour >= 0 && hour <= 23)
        let sOK = second.map { $0 >= 0 && $0 <= 59 } ?? true
        return h && minute >= 0 && minute <= 59 && sOK
    }
    /// Same wall-clock digits (ignoring whether a meridiem label is shown).
    func sameClock(as o: TimeValue) -> Bool {
        hour == o.hour && minute == o.minute && (o.second == nil || o.second == second)
    }
}

public struct TimeFormat: Equatable, Sendable {
    public let separator: String   // ".", ":", "-", or "" (compact)
    public let hasSeconds: Bool
    public let padHour: Bool
    public let meridiem: Bool
    public let meridiemSpace: Bool

    public func format(_ t: TimeValue) -> String {
        let h = padHour ? String(format: "%02ld", t.hour) : String(t.hour)
        let m = String(format: "%02ld", t.minute)
        var out = h + separator + m
        if hasSeconds, let s = t.second { out += separator + String(format: "%02ld", s) }
        if meridiem, let mer = t.meridiem { out += (meridiemSpace ? " " : "") + mer }
        return out
    }

    /// Compact layouts to try when an output is a bare digit run (143000 / 1430).
    static let compact: [TimeFormat] = [
        TimeFormat(separator: "", hasSeconds: true, padHour: true, meridiem: false, meridiemSpace: false),
        TimeFormat(separator: "", hasSeconds: false, padHour: true, meridiem: false, meridiemSpace: false),
    ]
}

struct TimeMatch { let range: Range<String.Index>; let time: TimeValue; let format: TimeFormat; let raw: String }

enum TimeRecognizer {
    // Conservative: require seconds, OR a meridiem, OR a colon — so we don't eat
    // version numbers / decimals like "v2.30".
    private static let patterns = [
        "(?<![0-9])([0-9]{1,2})([.:\\-])([0-9]{2})\\2([0-9]{2})(?![0-9])( ?[AaPp][Mm])?", // H s MM s SS [mer]
        "(?<![0-9])([0-9]{1,2})([.:\\-])([0-9]{2})(?![0-9])( ?[AaPp][Mm])",                // H s MM mer
        "(?<![0-9])([0-9]{1,2})(:)([0-9]{2})(?![0-9])",                                     // H:MM (colon)
    ]

    static func matches(in s: String) -> [TimeMatch] {
        var result: [TimeMatch] = []
        var claimed: [Range<String.Index>] = []
        for (idx, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for m in regex.matches(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) {
                guard let r = Range(m.range, in: s), !claimed.contains(where: { $0.overlaps(r) }) else { continue }
                func grp(_ i: Int) -> String? { Range(m.range(at: i), in: s).map { String(s[$0]) } }
                guard let hStr = grp(1), let hour = Int(hStr), let minute = Int(grp(3) ?? "") else { continue }
                let second = idx == 0 ? grp(4).flatMap { Int($0) } : nil
                let merRaw = (idx == 0 ? grp(5) : idx == 1 ? grp(4) : nil)
                let meridiem = merRaw?.trimmingCharacters(in: .whitespaces).uppercased()
                let sep = idx == 2 ? ":" : (grp(2) ?? ".")
                let time = TimeValue(hour: hour, minute: minute, second: second,
                                     meridiem: (meridiem?.isEmpty ?? true) ? nil : meridiem)
                guard time.isValid else { continue }
                let format = TimeFormat(separator: sep, hasSeconds: second != nil, padHour: hStr.count == 2,
                                        meridiem: time.meridiem != nil, meridiemSpace: merRaw?.hasPrefix(" ") ?? false)
                result.append(TimeMatch(range: r, time: time, format: format, raw: String(s[r])))
                claimed.append(r)
            }
        }
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}

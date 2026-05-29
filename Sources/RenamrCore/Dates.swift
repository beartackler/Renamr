import Foundation

/// A calendar date reduced to the only fields filenames ever carry.
public struct SimpleDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public var isValid: Bool {
        year >= 1900 && year <= 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31
    }
}

/// A recognized date layout. The engine learns the *output* layout from one
/// example and re-emits every other file's date by re-parse-and-reformat,
/// rather than doing string surgery — so `20240115 -> 2024-01-15` generalizes
/// to `20240116 -> 2024-01-16` instead of blindly inserting dashes at offsets.
public enum DateFormatSig: String, CaseIterable, Sendable {
    case compact          // 20240115
    case dashYMD          // 2024-01-15
    case slashYMD         // 2024/01/15
    case dotYMD           // 2024.01.15
    case underscoreYMD    // 2024_01_15
    case slashMDY         // 01/15/2024
    case dashDMY          // 15-01-2024
    case dotDMY           // 15.01.2024  (output formats below; reformat targets)
    case slashDMY         // 15/01/2024
    case dashMDY          // 01-15-2024

    /// ICU regex. Compact uses digit lookarounds so it never grabs part of a
    /// longer numeric run (e.g. a 10-digit serial or a counter).
    var regexPattern: String {
        switch self {
        // Year stays 4 digits; month/day allow 1–2 so 2024-1-5 parses like 2024-01-05.
        case .compact:       return "(?<![0-9])([0-9]{4})([0-9]{2})([0-9]{2})(?![0-9])"
        case .dashYMD:       return "([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})"
        case .slashYMD:      return "([0-9]{4})/([0-9]{1,2})/([0-9]{1,2})"
        case .dotYMD:        return "([0-9]{4})\\.([0-9]{1,2})\\.([0-9]{1,2})"
        case .underscoreYMD: return "([0-9]{4})_([0-9]{1,2})_([0-9]{1,2})"
        case .slashMDY:      return "([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})"
        case .dashDMY:       return "([0-9]{1,2})-([0-9]{1,2})-([0-9]{4})"
        case .dotDMY:        return "([0-9]{1,2})\\.([0-9]{1,2})\\.([0-9]{4})"
        case .slashDMY:      return "([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})"
        case .dashMDY:       return "([0-9]{1,2})-([0-9]{1,2})-([0-9]{4})"
        }
    }

    /// 1-based capture-group indices for (year, month, day).
    var groupOrder: (y: Int, m: Int, d: Int) {
        switch self {
        case .compact, .dashYMD, .slashYMD, .dotYMD, .underscoreYMD: return (1, 2, 3)
        case .slashMDY, .dashMDY: return (3, 1, 2)
        case .dashDMY, .dotDMY, .slashDMY: return (3, 2, 1)
        }
    }

    public func format(_ d: SimpleDate) -> String {
        let y = String(format: "%04ld", d.year)
        let m = String(format: "%02ld", d.month)
        let day = String(format: "%02ld", d.day)
        switch self {
        case .compact:       return "\(y)\(m)\(day)"
        case .dashYMD:       return "\(y)-\(m)-\(day)"
        case .slashYMD:      return "\(y)/\(m)/\(day)"
        case .dotYMD:        return "\(y).\(m).\(day)"
        case .underscoreYMD: return "\(y)_\(m)_\(day)"
        case .slashMDY:      return "\(m)/\(day)/\(y)"
        case .dashDMY:       return "\(day)-\(m)-\(y)"
        case .dotDMY:        return "\(day).\(m).\(y)"
        case .slashDMY:      return "\(day)/\(m)/\(y)"
        case .dashMDY:       return "\(m)-\(day)-\(y)"
        }
    }
}

struct DateMatch {
    let range: Range<String.Index>
    let date: SimpleDate
    let format: DateFormatSig
    let raw: String
}

enum DateRecognizer {
    /// Tried most-specific / least-ambiguous first so `2024-01-15` is read as
    /// dashYMD, and the bare 8-digit compact form is the last resort.
    static let priority: [DateFormatSig] = [
        .dashYMD, .slashYMD, .dotYMD, .underscoreYMD,
        .slashMDY, .slashDMY, .dashDMY, .dashMDY, .dotDMY,
        .compact,
    ]

    static let monthNumbers: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    ]

    /// Textual dates with a month name: "January 5, 2024", "Jan 5 2024",
    /// "5 Jan 2024", "5 January 2024" → a real date. Recognized BEFORE the numeric
    /// layouts so they claim their span first.
    private static func appendTextual(in s: String, _ result: inout [DateMatch], _ claimed: inout [Range<String.Index>]) {
        let monthName = "jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec"
        let patterns: [(String, isMDY: Bool)] = [
            ("(?i)\\b(\(monthName))[a-z]*\\.?\\s+([0-9]{1,2})(?:st|nd|rd|th)?,?\\s+([0-9]{4})\\b", true),
            ("(?i)\\b([0-9]{1,2})(?:st|nd|rd|th)?\\s+(\(monthName))[a-z]*\\.?\\s+([0-9]{4})\\b", false),
        ]
        for (pattern, isMDY) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for m in regex.matches(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)) {
                guard let r = Range(m.range, in: s), !claimed.contains(where: { $0.overlaps(r) }) else { continue }
                let monthGroup = isMDY ? 1 : 2
                let dayGroup = isMDY ? 2 : 1
                guard
                    let mr = Range(m.range(at: monthGroup), in: s),
                    let dr = Range(m.range(at: dayGroup), in: s),
                    let yr = Range(m.range(at: 3), in: s),
                    let month = monthNumbers[String(s[mr]).lowercased().prefix(3).lowercased()],
                    let day = Int(s[dr]), let year = Int(s[yr])
                else { continue }
                let date = SimpleDate(year: year, month: month, day: day)
                guard date.isValid else { continue }
                result.append(DateMatch(range: r, date: date, format: .dashYMD, raw: String(s[r])))
                claimed.append(r)
            }
        }
    }

    static func matches(in s: String) -> [DateMatch] {
        var result: [DateMatch] = []
        var claimed: [Range<String.Index>] = []
        appendTextual(in: s, &result, &claimed)
        for sig in priority {
            guard let regex = try? NSRegularExpression(pattern: sig.regexPattern) else { continue }
            let nsRange = NSRange(s.startIndex..<s.endIndex, in: s)
            for m in regex.matches(in: s, range: nsRange) {
                guard let r = Range(m.range, in: s) else { continue }
                if claimed.contains(where: { $0.overlaps(r) }) { continue }
                let (yi, mi, di) = sig.groupOrder
                guard
                    let yr = Range(m.range(at: yi), in: s),
                    let mr = Range(m.range(at: mi), in: s),
                    let dr = Range(m.range(at: di), in: s),
                    let y = Int(s[yr]), let mo = Int(s[mr]), let d = Int(s[dr])
                else { continue }
                let date = SimpleDate(year: y, month: mo, day: d)
                guard date.isValid else { continue }
                result.append(DateMatch(range: r, date: date, format: sig, raw: String(s[r])))
                claimed.append(r)
            }
        }
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}

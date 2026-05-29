import Foundation

/// The semantic class of a filename segment. Generalization happens over these
/// typed segments ("the 1st date", "the 3rd word") rather than over raw
/// character offsets — which is what lets one example teach the whole folder.
public enum TokenKind: Equatable, Sendable {
    case word        // a run of letters
    case number      // a run of digits
    case date        // a recognized date (may span separators, e.g. 2024-01-15)
    case time        // a recognized clock time (14.22.07, 8.15 AM, 9:41)
    case separator   // a run of non-alphanumeric characters
}

public struct Token: Equatable, Sendable {
    public let text: String
    public let kind: TokenKind
    public let intValue: Int?         // .number
    public let padWidth: Int?         // .number — original digit count
    public let date: SimpleDate?      // .date
    public let dateFormat: DateFormatSig?
    public let time: TimeValue?       // .time
    public let timeFormat: TimeFormat?

    static func word(_ t: String) -> Token {
        Token(text: t, kind: .word, intValue: nil, padWidth: nil, date: nil, dateFormat: nil, time: nil, timeFormat: nil)
    }
    static func number(_ t: String) -> Token {
        Token(text: t, kind: .number, intValue: Int(t), padWidth: t.count, date: nil, dateFormat: nil, time: nil, timeFormat: nil)
    }
    static func separator(_ t: String) -> Token {
        Token(text: t, kind: .separator, intValue: nil, padWidth: nil, date: nil, dateFormat: nil, time: nil, timeFormat: nil)
    }
    static func dateToken(_ raw: String, _ d: SimpleDate, _ f: DateFormatSig) -> Token {
        Token(text: raw, kind: .date, intValue: nil, padWidth: nil, date: d, dateFormat: f, time: nil, timeFormat: nil)
    }
    static func timeToken(_ raw: String, _ t: TimeValue, _ f: TimeFormat) -> Token {
        Token(text: raw, kind: .time, intValue: nil, padWidth: nil, date: nil, dateFormat: nil, time: t, timeFormat: f)
    }
}

public enum Tokenizer {
    /// Segment a filename stem (extension already removed) into typed tokens.
    /// Dates are recognized first and carved out as single tokens; the gaps
    /// between them are split on letter/digit/separator class transitions.
    public static func tokenize(_ stem: String) -> [Token] {
        let dates = DateRecognizer.matches(in: stem)
        var tokens: [Token] = []
        var cursor = stem.startIndex
        for dm in dates {
            if cursor < dm.range.lowerBound {
                tokens.append(contentsOf: carveTimes(String(stem[cursor..<dm.range.lowerBound])))
            }
            tokens.append(.dateToken(dm.raw, dm.date, dm.format))
            cursor = dm.range.upperBound
        }
        if cursor < stem.endIndex {
            tokens.append(contentsOf: carveTimes(String(stem[cursor..<stem.endIndex])))
        }
        return tokens
    }

    /// Carve clock times out of a date-free span, class-run the rest.
    private static func carveTimes(_ s: String) -> [Token] {
        let times = TimeRecognizer.matches(in: s)
        guard !times.isEmpty else { return classRuns(s) }
        var tokens: [Token] = []
        var cursor = s.startIndex
        for tm in times {
            if cursor < tm.range.lowerBound { tokens.append(contentsOf: classRuns(String(s[cursor..<tm.range.lowerBound]))) }
            tokens.append(.timeToken(tm.raw, tm.time, tm.format))
            cursor = tm.range.upperBound
        }
        if cursor < s.endIndex { tokens.append(contentsOf: classRuns(String(s[cursor..<s.endIndex]))) }
        return tokens
    }

    private enum CharClass { case letter, digit, separator }

    private static func classify(_ c: Character) -> CharClass {
        if c.isLetter { return .letter }
        if c.isNumber { return .digit }
        return .separator
    }

    /// Split a date-free substring into maximal same-class runs. This is what
    /// turns `DSC0931` into [word "DSC", number "0931"].
    private static func classRuns(_ s: String) -> [Token] {
        var out: [Token] = []
        var current = ""
        var currentClass: CharClass?
        func flush() {
            guard let cls = currentClass, !current.isEmpty else { return }
            switch cls {
            case .letter: out.append(.word(current))
            case .digit: out.append(.number(current))
            case .separator: out.append(.separator(current))
            }
            current = ""
        }
        for c in s {
            let cls = classify(c)
            if cls != currentClass { flush(); currentClass = cls }
            current.append(c)
        }
        flush()
        return out
    }
}

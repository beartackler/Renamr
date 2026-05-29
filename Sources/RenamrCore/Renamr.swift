import Foundation

/// A proposed rename for one file.
public struct RenamePreview: Equatable, Sendable, Identifiable {
    public let original: String
    public let proposed: String
    /// True when every field the program references was found in this file.
    public let isConfident: Bool
    public let note: String?

    public init(original: String, proposed: String, isConfident: Bool, note: String?) {
        self.original = original
        self.proposed = proposed
        self.isConfident = isConfident
        self.note = note
    }

    /// Filenames are unique within a folder, so the original name is a stable id.
    public var id: String { original }

    /// True when this file would actually be renamed (confident and different).
    public var isChange: Bool { isConfident && proposed != original }
}

/// Raised when one example leaves genuine ambiguity: at least two equally-good
/// programs survive and produce *different* names for some file. Resolving it is
/// a single extra example on that file.
public struct DisagreementPrompt: Equatable, Sendable {
    /// The file where the surviving programs disagree the most (most distinct outcomes).
    public let file: String
    /// The competing proposed names for that file (what the rival rules would do).
    public let options: [String]
}

public struct SynthesisResult: Sendable {
    /// The chosen program, or nil if no example was provided.
    public let program: Program?
    public let previews: [RenamePreview]
    /// Non-fatal problems (e.g. the examples couldn't be reconciled into one rule).
    public let warnings: [String]
    /// Set when a second example would resolve real ambiguity. nil when confident.
    public let needsMoreInfo: DisagreementPrompt?
}

/// Public entry point. Give it one (or a few) corrected filenames and the folder;
/// it infers the transformation, previews it, and tells you when one more example
/// would resolve an ambiguity.
public enum Renamr {

    public static func synthesize(
        examples: [(before: String, after: String)],
        files: [String]
    ) -> SynthesisResult {
        guard let first = examples.first else {
            return SynthesisResult(
                program: nil,
                previews: files.map { RenamePreview(original: $0, proposed: $0, isConfident: false, note: "No example provided") },
                warnings: ["No example provided"],
                needsMoreInfo: nil
            )
        }

        // Build the competing programs implied by the first example (primary +
        // one variant per ambiguous field), then keep only those consistent with
        // every example given. Extra examples collapse the ambiguity.
        let candidates = candidatePrograms(before: first.before, after: first.after,
                                           exampleIndex: files.firstIndex(of: first.before) ?? 0)
        let consistent = candidates.filter { program in
            examples.allSatisfy { example in
                apply(program: program, to: example.before, index: files.firstIndex(of: example.before) ?? 0).proposed == example.after
            }
        }
        var warnings: [String] = []
        let alive: [Program]
        if consistent.isEmpty {
            alive = Array(candidates.prefix(1))
            warnings.append("Couldn't find a single rule that fits all your examples — using the closest.")
        } else {
            alive = consistent
        }

        let best = alive[0]   // all alive programs tie on the examples; primary is first
        let previews = files.enumerated().map { (index, file) -> RenamePreview in
            let result = apply(program: best, to: file, index: index)
            if let proposed = result.proposed, result.resolved {
                return RenamePreview(original: file, proposed: proposed, isConfident: true, note: nil)
            }
            // Not confident → show the file unchanged rather than a half-built
            // string. We flag it; we never propose a name we don't trust.
            return RenamePreview(
                original: file,
                proposed: file,
                isConfident: false,
                note: "Some fields couldn't be located in this file — skipped"
            )
        }

        let needsMoreInfo = disagreement(programs: alive, files: files)
        return SynthesisResult(program: best, previews: previews, warnings: warnings, needsMoreInfo: needsMoreInfo)
    }

    /// Apply a learned program to a single filename. `index` is the file's
    /// position in the folder, used only by `.sequence` (renumbering).
    public static func apply(program: Program, to filename: String, index: Int = 0) -> (proposed: String?, resolved: Bool) {
        let (stem, ext) = splitName(filename)
        let byKind = indexByKind(Tokenizer.tokenize(stem))
        var out = ""
        var resolved = true

        for instruction in program.instructions {
            switch instruction {
            case .literal(let s):
                out += s
            case .copy(let ref, let transform):
                if let token = lookup(ref, in: byKind) { out += transform.apply(token.text) } else { resolved = false }
            case .prefix(let ref, let length, let transform):
                if let token = lookup(ref, in: byKind), token.text.count >= length {
                    out += transform.apply(String(token.text.prefix(length)))
                } else { resolved = false }
            case .copyRest(let kind, let from, let separator, let transform):
                let tokens = byKind[kind] ?? []
                if from < tokens.count {
                    out += tokens[from...].map { transform.apply($0.text) }.joined(separator: separator)
                } else { resolved = false }
            case .dateReformat(let ref, let format):
                if let token = lookup(ref, in: byKind), let date = token.date { out += format.format(date) } else { resolved = false }
            case .timeReformat(let ref, let format):
                if let token = lookup(ref, in: byKind), let time = token.time { out += format.format(time) } else { resolved = false }
            case .number(let ref, let padWidth):
                if let token = lookup(ref, in: byKind), let value = token.intValue { out += formatNumber(value, pad: padWidth) } else { resolved = false }
            case .sequence(let start, let step, let padWidth):
                out += formatNumber(start + index * step, pad: padWidth)
            case .normalize(let separator, let transform):
                for token in Tokenizer.tokenize(stem) {
                    switch token.kind {
                    case .separator: out += separator
                    case .word: out += transform.apply(token.text)
                    default: out += token.text
                    }
                }
            }
        }

        switch program.ext {
        case .keepOriginal: if !ext.isEmpty { out += "." + ext }
        case .constant(let e): if !e.isEmpty { out += "." + e }
        case .transformCase(let t): if !ext.isEmpty { out += "." + t.apply(ext) }
        }
        return (out, resolved)
    }

    // MARK: - Candidate programs (the version space, kept small)

    /// All programs implied by a single example: the primary (cheapest explanation
    /// per output token) plus, for each *ambiguous* token (a tie at the minimal
    /// cost), one variant that flips just that token. Single-flip variants are
    /// enough to detect "which field did you mean?" disagreements while staying
    /// bounded — no combinatorial blow-up.
    static func candidatePrograms(before: String, after: String, exampleIndex: Int = 0) -> [Program] {
        let (beforeStem, beforeExt) = splitName(before)
        let (afterStem, afterExt) = splitName(after)

        // Whole-name separator/case remap (slug → Title Case, _ → -, dots → spaces)
        // generalizes across any structure, so it's its own program when it fits.
        if let normalize = detectNormalize(beforeStem: beforeStem, afterStem: afterStem,
                                           ext: extensionPolicy(from: beforeExt, to: afterExt)) {
            return [normalize]
        }

        let byKind = indexByKind(Tokenizer.tokenize(beforeStem))
        let outputTokens = Tokenizer.tokenize(afterStem)

        var perToken: [[Instruction]] = []
        for out in outputTokens {
            let cands = explanations(for: out, byKind: byKind, exampleIndex: exampleIndex)
            let minCost = cands.map(\.1).min() ?? 12
            var tier = uniqued(cands.filter { $0.1 == minCost }.map(\.0))
            tier.sort { refOrdinal($0) < refOrdinal($1) }
            perToken.append(tier.isEmpty ? [.literal(out.text)] : tier)
        }

        let extPolicy = extensionPolicy(from: beforeExt, to: afterExt)
        let wordCount = byKind[.word]?.count ?? 0
        let primary = perToken.map { $0[0] }
        var programs: [[Instruction]] = [primary]
        for (index, choices) in perToken.enumerated() where choices.count > 1 {
            for alternative in choices.dropFirst() {
                var variant = primary
                variant[index] = alternative
                programs.append(variant)
            }
        }
        // Collapse a trailing run of word-copies that reaches the LAST word into a
        // single "keep the rest" instruction, so variable-length tails (song or
        // movie titles) generalize instead of silently dropping words.
        return programs.map { Program(instructions: collapseRest($0, wordCount: wordCount), ext: extPolicy) }
    }

    /// If the program ends with copy(word#k), sep, copy(word#k+1), …, copy(word#last)
    /// — a consecutive run of same-cased word copies, joined by one separator,
    /// reaching the final input word — replace that run with `.copyRest`.
    private static func collapseRest(_ program: [Instruction], wordCount: Int) -> [Instruction] {
        guard wordCount > 0, let last = program.last,
              case let .copy(lastRef, transform) = last,
              lastRef.kind == .word, lastRef.ordinal == wordCount - 1
        else { return program }

        var ordinals = [lastRef.ordinal]
        var separator: String?
        var runStart = program.count - 1
        var i = program.count - 2
        while i - 1 >= 0 {
            guard case let .literal(lit) = program[i],
                  case let .copy(ref, t) = program[i - 1],
                  ref.kind == .word, t == transform, ref.ordinal == ordinals.last! - 1,
                  separator == nil || separator == lit
            else { break }
            separator = lit
            ordinals.append(ref.ordinal)
            runStart = i - 1
            i -= 2
        }

        guard ordinals.count >= 2, let sep = separator, let from = ordinals.last else { return program }
        var result = Array(program[0..<runStart])
        result.append(.copyRest(.word, from: from, separator: sep, transform))
        return result
    }

    /// Every way an input token could explain one output token, with a cost.
    /// The simplicity prior: copying/transforming real data is cheap, hard-coding
    /// a data-looking literal is expensive, separators-as-literals are cheap.
    private static func explanations(for out: Token, byKind: [TokenKind: [Token]], exampleIndex: Int) -> [(Instruction, Int)] {
        var candidates: [(Instruction, Int)] = []
        for (kind, tokens) in byKind {
            if kind == .separator { continue }   // never reference separators; they become literals
            for (ordinal, token) in tokens.enumerated() {
                let ref = SourceRef(kind: kind, ordinal: ordinal)
                if token.text == out.text {
                    candidates.append((.copy(ref, .identity), 1))
                }
                for transform in [CaseTransform.lower, .upper, .capitalizeFirst] where transform.apply(token.text) == out.text && token.text != out.text {
                    candidates.append((.copy(ref, transform), 2))
                }
                // Abbreviation: output is the first N chars of a word (January -> Jan).
                if kind == .word, out.text.count >= 1, out.text.count < token.text.count {
                    let head = String(token.text.prefix(out.text.count))
                    for transform in [CaseTransform.identity, .lower, .upper, .capitalizeFirst] where transform.apply(head) == out.text {
                        candidates.append((.prefix(ref, length: out.text.count, transform), 3))
                        break
                    }
                }
                if kind == .date, let date = token.date {
                    for format in DateFormatSig.allCases where format.format(date) == out.text {
                        candidates.append((.dateReformat(ref, format), 2))
                    }
                }
                if kind == .time, let inTime = token.time {
                    // Output is a time token in some layout we can re-emit (no 12↔24 math).
                    if out.kind == .time, let outFmt = out.timeFormat, outFmt.format(inTime) == out.text {
                        candidates.append((.timeReformat(ref, outFmt), 2))
                    }
                    // Output is a bare digit run (e.g. 143000 / 1430).
                    if out.kind == .number {
                        for fmt in TimeFormat.compact where fmt.format(inTime) == out.text {
                            candidates.append((.timeReformat(ref, fmt), 2))
                        }
                    }
                }
                if kind == .number, let value = token.intValue, out.text.allSatisfy({ $0.isNumber }) {
                    for pad in [0, out.text.count] {
                        let formatted = formatNumber(value, pad: pad)
                        if formatted == out.text && formatted != token.text {
                            candidates.append((.number(ref, padWidth: pad), 2))
                        }
                    }
                }
            }
        }
        // A number with no source in the filename → likely a fresh 1,2,3… sequence
        // by file position (the classic camera dump). Cheaper than a literal,
        // dearer than copying a real source number, so it only wins for orphans.
        // BUT skip it when the number looks EXTRACTED from a longer number (e.g.
        // 0115 out of 20240115) — that's not a sequence, and guessing one corrupts.
        if out.kind == .number, let value = Int(out.text) {
            let looksExtracted = out.text.count >= 2 && byKind.values.flatMap { $0 }.contains {
                $0.text.count > out.text.count && $0.text.contains(out.text)
            }
            if !looksExtracted {
                candidates.append((.sequence(start: value - exampleIndex, step: 1, padWidth: out.text.count), 6))
            }
        }

        candidates.append((.literal(out.text), out.kind == .separator ? 1 : 12))
        return candidates
    }

    /// Among surviving programs, the file with the most distinct competing
    /// outcomes is the highest-information place to ask for one more example.
    private static func disagreement(programs: [Program], files: [String]) -> DisagreementPrompt? {
        guard programs.count > 1 else { return nil }
        var bestFile: String?
        var bestOptions: [String] = []
        for (index, file) in files.enumerated() {
            let outcomes = programs.map { apply(program: $0, to: file, index: index) }
            guard outcomes.allSatisfy(\.resolved) else { continue }
            let distinct = Set(outcomes.compactMap(\.proposed))
            if distinct.count > bestOptions.count {
                bestOptions = distinct.sorted()
                bestFile = file
            }
        }
        guard let file = bestFile, bestOptions.count > 1 else { return nil }
        return DisagreementPrompt(file: file, options: bestOptions)
    }

    // MARK: - Helpers

    /// Same extension, different case (PHOTO.JPG -> photo.jpg) → re-case each
    /// file's own extension rather than forcing a constant (which would wrongly
    /// turn a .png into a .jpg). A genuine change/addition stays constant.
    private static func extensionPolicy(from before: String, to after: String) -> ExtensionPolicy {
        if before == after { return .keepOriginal }
        if before.lowercased() == after.lowercased() {
            for transform in [CaseTransform.lower, .upper, .capitalizeFirst] where transform.apply(before) == after {
                return .transformCase(transform)
            }
        }
        return .constant(after)
    }

    /// The case transform mapping `from` → `to`, or nil if none does.
    private static func caseTransformBetween(_ from: String, _ to: String) -> CaseTransform? {
        for t in [CaseTransform.identity, .lower, .upper, .capitalizeFirst] where t.apply(from) == to { return t }
        return nil
    }

    /// Detect a pure separator-remap + uniform word re-casing (same token structure,
    /// only separators and letter-case change) — e.g. "a_b_c" → "a-b-c", or
    /// "the-best-recipe" → "The Best Recipe". Returns a `.normalize` program if so.
    private static func detectNormalize(beforeStem: String, afterStem: String, ext: ExtensionPolicy) -> Program? {
        let before = Tokenizer.tokenize(beforeStem)
        let after = Tokenizer.tokenize(afterStem)
        guard before.count == after.count, before.count >= 2 else { return nil }

        var transform: CaseTransform?
        var targetSeparator: String?
        var separatorChanged = false

        for (b, a) in zip(before, after) {
            guard b.kind == a.kind else { return nil }   // structure must match exactly
            switch b.kind {
            case .separator:
                if let t = targetSeparator { if t != a.text { return nil } } else { targetSeparator = a.text }
                if a.text != b.text { separatorChanged = true }
            case .word:
                guard let t = caseTransformBetween(b.text, a.text) else { return nil }
                if t != .identity {
                    if let existing = transform, existing != t { return nil }
                    transform = t
                }
            default:
                guard b.text == a.text else { return nil }   // numbers/dates must be identical
            }
        }

        let caseT = transform ?? .identity
        guard separatorChanged || caseT != .identity else { return nil }   // must actually change something
        return Program(instructions: [.normalize(separator: targetSeparator ?? "", transform: caseT)], ext: ext)
    }

    private static func uniqued(_ instructions: [Instruction]) -> [Instruction] {
        var result: [Instruction] = []
        for instruction in instructions where !result.contains(instruction) { result.append(instruction) }
        return result
    }

    private static func refOrdinal(_ instruction: Instruction) -> Int {
        switch instruction {
        case .copy(let r, _): return r.ordinal
        case .prefix(let r, _, _): return r.ordinal
        case .copyRest(_, let from, _, _): return from
        case .dateReformat(let r, _): return r.ordinal
        case .timeReformat(let r, _): return r.ordinal
        case .number(let r, _): return r.ordinal
        case .sequence: return Int.max - 1
        case .normalize: return Int.max
        case .literal: return Int.max
        }
    }

    private static func formatNumber(_ value: Int, pad: Int) -> String {
        pad <= 0 ? String(value) : String(format: "%0\(pad)ld", value)
    }

    private static func indexByKind(_ tokens: [Token]) -> [TokenKind: [Token]] {
        var result: [TokenKind: [Token]] = [:]
        for token in tokens { result[token.kind, default: []].append(token) }
        return result
    }

    private static func lookup(_ ref: SourceRef, in byKind: [TokenKind: [Token]]) -> Token? {
        guard let arr = byKind[ref.kind], ref.ordinal < arr.count else { return nil }
        return arr[ref.ordinal]
    }

    /// Split into (stem, extension) using path semantics. "a.tar.gz" -> ("a.tar", "gz").
    static func splitName(_ filename: String) -> (stem: String, ext: String) {
        let ns = filename as NSString
        return (ns.deletingPathExtension, ns.pathExtension)
    }
}

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
        let candidates = candidatePrograms(before: first.before, after: first.after)
        let consistent = candidates.filter { program in
            examples.allSatisfy { apply(program: program, to: $0.before).proposed == $0.after }
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
        let previews = files.map { file -> RenamePreview in
            let result = apply(program: best, to: file)
            if let proposed = result.proposed, result.resolved {
                return RenamePreview(original: file, proposed: proposed, isConfident: true, note: nil)
            }
            return RenamePreview(
                original: file,
                proposed: result.proposed ?? file,
                isConfident: false,
                note: "Some fields could not be located in this file"
            )
        }

        let needsMoreInfo = disagreement(programs: alive, files: files)
        return SynthesisResult(program: best, previews: previews, warnings: warnings, needsMoreInfo: needsMoreInfo)
    }

    /// Apply a learned program to a single filename.
    public static func apply(program: Program, to filename: String) -> (proposed: String?, resolved: Bool) {
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
            case .dateReformat(let ref, let format):
                if let token = lookup(ref, in: byKind), let date = token.date { out += format.format(date) } else { resolved = false }
            case .number(let ref, let padWidth):
                if let token = lookup(ref, in: byKind), let value = token.intValue { out += formatNumber(value, pad: padWidth) } else { resolved = false }
            }
        }

        switch program.ext {
        case .keepOriginal: if !ext.isEmpty { out += "." + ext }
        case .constant(let e): if !e.isEmpty { out += "." + e }
        }
        return (out, resolved)
    }

    // MARK: - Candidate programs (the version space, kept small)

    /// All programs implied by a single example: the primary (cheapest explanation
    /// per output token) plus, for each *ambiguous* token (a tie at the minimal
    /// cost), one variant that flips just that token. Single-flip variants are
    /// enough to detect "which field did you mean?" disagreements while staying
    /// bounded — no combinatorial blow-up.
    static func candidatePrograms(before: String, after: String) -> [Program] {
        let (beforeStem, beforeExt) = splitName(before)
        let (afterStem, afterExt) = splitName(after)
        let byKind = indexByKind(Tokenizer.tokenize(beforeStem))
        let outputTokens = Tokenizer.tokenize(afterStem)

        var perToken: [[Instruction]] = []
        for out in outputTokens {
            let cands = explanations(for: out, byKind: byKind)
            let minCost = cands.map(\.1).min() ?? 12
            var tier = uniqued(cands.filter { $0.1 == minCost }.map(\.0))
            tier.sort { refOrdinal($0) < refOrdinal($1) }
            perToken.append(tier.isEmpty ? [.literal(out.text)] : tier)
        }

        let extPolicy: ExtensionPolicy = (beforeExt == afterExt) ? .keepOriginal : .constant(afterExt)
        let primary = perToken.map { $0[0] }
        var programs: [[Instruction]] = [primary]
        for (index, choices) in perToken.enumerated() where choices.count > 1 {
            for alternative in choices.dropFirst() {
                var variant = primary
                variant[index] = alternative
                programs.append(variant)
            }
        }
        return programs.map { Program(instructions: $0, ext: extPolicy) }
    }

    /// Every way an input token could explain one output token, with a cost.
    /// The simplicity prior: copying/transforming real data is cheap, hard-coding
    /// a data-looking literal is expensive, separators-as-literals are cheap.
    private static func explanations(for out: Token, byKind: [TokenKind: [Token]]) -> [(Instruction, Int)] {
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
                if kind == .date, let date = token.date {
                    for format in DateFormatSig.allCases where format.format(date) == out.text {
                        candidates.append((.dateReformat(ref, format), 2))
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
        candidates.append((.literal(out.text), out.kind == .separator ? 1 : 12))
        return candidates
    }

    /// Among surviving programs, the file with the most distinct competing
    /// outcomes is the highest-information place to ask for one more example.
    private static func disagreement(programs: [Program], files: [String]) -> DisagreementPrompt? {
        guard programs.count > 1 else { return nil }
        var bestFile: String?
        var bestOptions: [String] = []
        for file in files {
            let outcomes = programs.map { apply(program: $0, to: file) }
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

    private static func uniqued(_ instructions: [Instruction]) -> [Instruction] {
        var result: [Instruction] = []
        for instruction in instructions where !result.contains(instruction) { result.append(instruction) }
        return result
    }

    private static func refOrdinal(_ instruction: Instruction) -> Int {
        switch instruction {
        case .copy(let r, _): return r.ordinal
        case .dateReformat(let r, _): return r.ordinal
        case .number(let r, _): return r.ordinal
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

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

public struct SynthesisResult: Sendable {
    /// The inferred program, or nil if no example was provided.
    public let program: Program?
    public let previews: [RenamePreview]
    /// Non-fatal problems (e.g. the program could not reproduce a given example).
    public let warnings: [String]
}

/// Public entry point. Give it one (or a few) corrected filenames and the
/// folder; it infers the transformation and previews it across every file.
public enum Renamr {

    public static func synthesize(
        examples: [(before: String, after: String)],
        files: [String]
    ) -> SynthesisResult {
        guard let first = examples.first else {
            let previews = files.map {
                RenamePreview(original: $0, proposed: $0, isConfident: false, note: "No example provided")
            }
            return SynthesisResult(program: nil, previews: previews, warnings: ["No example provided"])
        }

        let program = inferProgram(before: first.before, after: first.after)

        var warnings: [String] = []
        for ex in examples {
            let result = apply(program: program, to: ex.before)
            if result.proposed != ex.after {
                warnings.append(
                    "Program does not reproduce example: \(ex.before) -> expected \(ex.after), got \(result.proposed ?? "<unresolved>")"
                )
            }
        }

        let previews = files.map { file -> RenamePreview in
            let result = apply(program: program, to: file)
            if let proposed = result.proposed, result.resolved {
                return RenamePreview(original: file, proposed: proposed, isConfident: true, note: nil)
            } else {
                return RenamePreview(
                    original: file,
                    proposed: result.proposed ?? file,
                    isConfident: false,
                    note: "Some fields could not be located in this file"
                )
            }
        }
        return SynthesisResult(program: program, previews: previews, warnings: warnings)
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
                if let token = lookup(ref, in: byKind) {
                    out += transform.apply(token.text)
                } else {
                    resolved = false
                }
            case .dateReformat(let ref, let format):
                if let token = lookup(ref, in: byKind), let date = token.date {
                    out += format.format(date)
                } else {
                    resolved = false
                }
            case .number(let ref, let padWidth):
                if let token = lookup(ref, in: byKind), let value = token.intValue {
                    out += formatNumber(value, pad: padWidth)
                } else {
                    resolved = false
                }
            }
        }

        switch program.ext {
        case .keepOriginal:
            if !ext.isEmpty { out += "." + ext }
        case .constant(let e):
            if !e.isEmpty { out += "." + e }
        }
        return (out, resolved)
    }

    // MARK: - Synthesis

    /// Infer a program from a single (before, after) pair.
    ///
    /// For each output token we enumerate every way an input token could
    /// explain it (identity / re-case / date-reformat / number-repad) plus the
    /// literal fallback, then pick the cheapest explanation. The cost function
    /// is the simplicity prior: a copy/transform of real data beats hard-coding
    /// a literal, while separators (which match no input token) fall through to
    /// cheap literals. That bias is what produces the "it just knew" behaviour
    /// from a single example.
    static func inferProgram(before: String, after: String) -> Program {
        let (beforeStem, beforeExt) = splitName(before)
        let (afterStem, afterExt) = splitName(after)
        let inputTokens = Tokenizer.tokenize(beforeStem)
        let outputTokens = Tokenizer.tokenize(afterStem)
        let byKind = indexByKind(inputTokens)

        var instructions: [Instruction] = []
        for outToken in outputTokens {
            let candidate = bestExplanation(for: outToken, byKind: byKind)
            instructions.append(candidate)
        }

        let extPolicy: ExtensionPolicy = (beforeExt == afterExt) ? .keepOriginal : .constant(afterExt)
        return Program(instructions: instructions, ext: extPolicy)
    }

    private struct Candidate { let instruction: Instruction; let cost: Int }

    private static func bestExplanation(for out: Token, byKind: [TokenKind: [Token]]) -> Instruction {
        var candidates: [Candidate] = []

        for (kind, tokens) in byKind {
            if kind == .separator { continue }   // never reference separators; they become literals
            for (ordinal, token) in tokens.enumerated() {
                let ref = SourceRef(kind: kind, ordinal: ordinal)

                if token.text == out.text {
                    candidates.append(Candidate(instruction: .copy(ref, .identity), cost: 1))
                }
                for transform in [CaseTransform.lower, .upper, .capitalizeFirst] {
                    if transform.apply(token.text) == out.text && token.text != out.text {
                        candidates.append(Candidate(instruction: .copy(ref, transform), cost: 2))
                    }
                }
                if kind == .date, let date = token.date {
                    for format in DateFormatSig.allCases where format.format(date) == out.text {
                        candidates.append(Candidate(instruction: .dateReformat(ref, format), cost: 2))
                    }
                }
                if kind == .number, let value = token.intValue, out.text.allSatisfy({ $0.isNumber }) {
                    for pad in [0, out.text.count] {
                        let formatted = formatNumber(value, pad: pad)
                        if formatted == out.text && formatted != token.text {
                            candidates.append(Candidate(instruction: .number(ref, padWidth: pad), cost: 2))
                        }
                    }
                }
            }
        }

        // Literal fallback: cheap for separators, expensive for data-looking tokens.
        let literalCost = (out.kind == .separator) ? 1 : 12
        candidates.append(Candidate(instruction: .literal(out.text), cost: literalCost))

        // Deterministic pick: lowest cost, then prefer non-literal, then lowest ordinal.
        let best = candidates.min { a, b in
            if a.cost != b.cost { return a.cost < b.cost }
            let aLit = isLiteral(a.instruction), bLit = isLiteral(b.instruction)
            if aLit != bLit { return !aLit }
            return refOrdinal(a.instruction) < refOrdinal(b.instruction)
        }
        return best?.instruction ?? .literal(out.text)
    }

    // MARK: - Helpers

    private static func isLiteral(_ i: Instruction) -> Bool {
        if case .literal = i { return true }
        return false
    }

    private static func refOrdinal(_ i: Instruction) -> Int {
        switch i {
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

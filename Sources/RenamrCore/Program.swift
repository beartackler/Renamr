import Foundation

/// How a copied token's text is re-cased on output.
public enum CaseTransform: Equatable, Sendable {
    case identity
    case lower
    case upper
    case capitalizeFirst   // "beach" -> "Beach"

    public func apply(_ s: String) -> String {
        switch self {
        case .identity: return s
        case .lower: return s.lowercased()
        case .upper: return s.uppercased()
        case .capitalizeFirst:
            guard let first = s.first else { return s }
            return String(first).uppercased() + s.dropFirst().lowercased()
        }
    }
}

/// A structural reference to a source token: "the Nth token of this kind".
/// Stable across files even when token counts differ, which is what makes the
/// learned program generalize.
public struct SourceRef: Equatable, Sendable {
    public let kind: TokenKind
    public let ordinal: Int
}

/// One unit of output. A `Program` is just an ordered list of these plus an
/// extension policy.
public enum Instruction: Equatable, Sendable {
    case literal(String)                              // a constant (typically a separator)
    case copy(SourceRef, CaseTransform)               // copy a source token, optionally re-cased
    case prefix(SourceRef, length: Int, CaseTransform) // first N chars of a word, re-cased (January -> Jan)
    case dateReformat(SourceRef, DateFormatSig)       // re-parse a source date, emit in a new layout
    case number(SourceRef, padWidth: Int)             // emit a source number with new zero-padding (0 = none)
}

public enum ExtensionPolicy: Equatable, Sendable {
    case keepOriginal                 // leave each file's extension untouched
    case constant(String)             // force a specific extension
    case transformCase(CaseTransform) // re-case each file's own extension (PNG -> png)
}

public struct Program: Equatable, Sendable {
    public var instructions: [Instruction]
    public var ext: ExtensionPolicy

    public init(instructions: [Instruction], ext: ExtensionPolicy) {
        self.instructions = instructions
        self.ext = ext
    }
}

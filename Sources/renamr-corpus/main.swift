import Foundation
import RenamrCore

// Runs a JSON corpus through the engine and reports gaps.
//   renamr-corpus <corpus.json>
// JSON: a top-level array (or {"scenarios":[...]}) of:
//   { exampleBefore, exampleAfter, files:[...], expected:[...], transform, inferable }

struct Scenario: Codable {
    let exampleBefore: String
    let exampleAfter: String
    let files: [String]
    let expected: [String]
    var transform: String?
    var inferable: Bool?
}
struct Wrapper: Codable { let scenarios: [Scenario] }

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first, let data = FileManager.default.contents(atPath: path) else {
    FileHandle.standardError.write(Data("usage: renamr-corpus <corpus.json>\n".utf8)); exit(2)
}
let scenarios: [Scenario] = (try? JSONDecoder().decode([Scenario].self, from: data))
    ?? ((try? JSONDecoder().decode(Wrapper.self, from: data))?.scenarios ?? [])
guard !scenarios.isEmpty else {
    FileHandle.standardError.write(Data("no scenarios decoded from \(path)\n".utf8)); exit(2)
}

var pass = 0, fail = 0
var inferableFails: [(Scenario, [String])] = []   // the real gaps
var hardHandled = 0                               // non-inferable we nailed anyway

for s in scenarios {
    // Skip malformed scenarios (expected must align with files, example present).
    guard s.files.count == s.expected.count, s.files.contains(s.exampleBefore) else { continue }
    let result = Renamr.synthesize(examples: [(s.exampleBefore, s.exampleAfter)], files: s.files)
    let got = result.previews.map(\.proposed)
    let ok = got == s.expected
    if ok {
        pass += 1
        if s.inferable == false { hardHandled += 1 }
    } else {
        fail += 1
        if s.inferable != false { inferableFails.append((s, got)) }
    }
}

print("=== Renamr corpus: \(scenarios.count) scenarios ===")
print("PASS \(pass)   FAIL \(fail)   (non-inferable cases the engine still nailed: \(hardHandled))")
print("\n--- INFERABLE FAILURES (the real gaps), \(inferableFails.count) ---")
// group by transform phrase
var byTransform: [String: Int] = [:]
for (s, _) in inferableFails { byTransform[s.transform ?? "?", default: 0] += 1 }
for (t, n) in byTransform.sorted(by: { $0.value > $1.value }) {
    print(String(format: "  %3d  %@", n, t))
}
print("\n--- examples ---")
for (s, got) in inferableFails.prefix(40) {
    print("• [\(s.transform ?? "?")]")
    print("   ex:   \(s.exampleBefore)  ->  \(s.exampleAfter)")
    print("   want: \(s.expected)")
    print("   got:  \(got)")
}

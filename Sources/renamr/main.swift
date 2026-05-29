import Foundation
import RenamrCore

// renamr <before> <after> <file> [file ...]
//   <before>/<after> : one example — an original name and your corrected name
//   files            : the names to transform by that example (often a glob)
//
// Example:
//   renamr "IMG_20240115_beach_DSC0931.jpg" "2024-01-15 Beach 0931.jpg" *.jpg

let args = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard args.count >= 3 else {
    fail("""
    Usage: renamr <before> <after> <file> [file ...]

      Rename a whole folder by example: correct ONE filename, and renamr
      infers the transformation and applies it to the rest.

      renamr "IMG_20240115_beach_DSC0931.jpg" "2024-01-15 Beach 0931.jpg" *.jpg
    """)
}

let before = args[0]
let after = args[1]
let files = Array(args.dropFirst(2))

let result = Renamr.synthesize(examples: [(before, after)], files: files)

for warning in result.warnings {
    FileHandle.standardError.write(Data(("warning: " + warning + "\n").utf8))
}

let confidentCount = result.previews.filter(\.isConfident).count
for preview in result.previews {
    let mark = preview.isConfident ? "✓" : "?"
    print("\(mark) \(preview.original)  ->  \(preview.proposed)")
}
print("—")
print("\(confidentCount)/\(result.previews.count) confident")

import Foundation
import AppKit
import UniformTypeIdentifiers
import RenamrCore

@MainActor
final class RenameModel: ObservableObject {
    /// Shared so the Finder Service and menu commands can reach the live model.
    static let shared = RenameModel()

    @Published var directoryURL: URL?
    @Published private(set) var files: [String] = []
    @Published var selectedFile: String?            // the file you're teaching with
    @Published var correctedName: String = ""        // your corrected name for it
    @Published private(set) var examples: [Example] = []   // committed corrections, in order
    @Published private(set) var previews: [RenamePreview] = []
    @Published private(set) var warnings: [String] = []
    @Published private(set) var needsMoreInfo: DisagreementPrompt?
    @Published private(set) var lastBatch: [Rename] = []
    @Published private(set) var preselected: Set<String> = []   // files handed in from Finder
    @Published var statusMessage: String = ""

    struct Example: Equatable { let before: String; let after: String }
    struct Rename: Equatable { let from: URL; let to: URL }

    var confidentChangeCount: Int { previews.filter(\.isChange).count }
    var hasFolder: Bool { directoryURL != nil }

    // MARK: - Getting a folder (drop, dialog, Finder, or a Service)

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
            else if let u = item as? URL { url = u }
            guard let resolved = url else { return }
            Task { @MainActor in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir)
                self.load(isDir.boolValue ? resolved : resolved.deletingLastPathComponent())
            }
        }
        return true
    }

    /// Entry point for the Finder right-click Service: a set of files the user
    /// selected. We open their folder and pre-highlight them.
    func loadFiles(urls: [URL]) {
        func isDirectory(_ u: URL) -> Bool {
            (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        }
        let fileURLs = urls.filter { !isDirectory($0) }
        guard let folder = (fileURLs.first ?? urls.first)?.deletingLastPathComponent() else { return }
        load(folder, preselect: Set(fileURLs.map(\.lastPathComponent)))
    }

    /// "Use the folder I'm already looking at." Reads the front Finder window via
    /// AppleScript (needs the one-time Automation permission for Finder).
    func openFrontmostFinderFolder() {
        let source = """
        set AppleScript's text item delimiters to linefeed
        tell application "Finder"
            if (count of Finder windows) is 0 then return ""
            set theTarget to target of front Finder window
            set folderPath to POSIX path of (theTarget as alias)
            set selPaths to ""
            repeat with anItem in (get selection)
                set selPaths to selPaths & POSIX path of (anItem as alias) & linefeed
            end repeat
            return folderPath & "::" & selPaths
        end tell
        """
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source),
              let output = script.executeAndReturnError(&errorInfo).stringValue, !output.isEmpty
        else {
            statusMessage = errorInfo != nil
                ? "Couldn't reach Finder — grant Renamr access in System Settings ▸ Privacy & Security ▸ Automation."
                : "Open a Finder window first, then try again."
            return
        }
        let parts = output.components(separatedBy: "::")
        guard let folderPath = parts.first, !folderPath.isEmpty else { return }
        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        let selection = parts.count > 1
            ? parts[1].split(separator: "\n").map { URL(fileURLWithPath: String($0)).lastPathComponent }
            : []
        load(folder, preselect: Set(selection))
    }

    func load(_ url: URL, preselect: Set<String> = []) {
        directoryURL = url
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        files = names.filter { !$0.hasPrefix(".") }.sorted()
        examples = []
        selectedFile = preselect.first.flatMap { files.contains($0) ? $0 : nil }
        correctedName = selectedFile ?? ""
        preselected = preselect
        lastBatch = []
        previews = identityPreviews()
        warnings = []
        needsMoreInfo = nil
        statusMessage = Voice.loaded(files.count)
        if selectedFile != nil { recompute() }
    }

    // MARK: - Teaching by example

    func selectExample(_ name: String) {
        commitActiveEdit()
        selectedFile = name
        correctedName = examples.first { $0.before == name }?.after ?? name
        recompute()
    }

    private func commitActiveEdit() {
        guard activeEditIsTeaching, let before = selectedFile else { return }
        if let index = examples.firstIndex(where: { $0.before == before }) {
            examples[index] = Example(before: before, after: correctedName)
        } else {
            examples.append(Example(before: before, after: correctedName))
        }
    }

    private var activeEditIsTeaching: Bool {
        guard let f = selectedFile else { return false }
        return !correctedName.isEmpty && correctedName != f
    }

    private func currentPairs() -> [(before: String, after: String)] {
        var pairs = examples
        if activeEditIsTeaching, let before = selectedFile {
            if let index = pairs.firstIndex(where: { $0.before == before }) {
                pairs[index] = Example(before: before, after: correctedName)
            } else {
                pairs.append(Example(before: before, after: correctedName))
            }
        }
        return pairs.map { (before: $0.before, after: $0.after) }
    }

    func recompute() {
        let pairs = currentPairs()
        guard !pairs.isEmpty else {
            previews = identityPreviews(); warnings = []; needsMoreInfo = nil
            return
        }
        let result = Renamr.synthesize(examples: pairs, files: files)
        previews = result.previews
        warnings = result.warnings
        needsMoreInfo = result.needsMoreInfo
    }

    /// Jump to the file Renamr is unsure about so the user can teach it.
    func teachAmbiguousFile() {
        guard let file = needsMoreInfo?.file else { return }
        selectExample(file)
    }

    // MARK: - Apply / undo

    func apply() {
        guard let dir = directoryURL else { return }
        commitActiveEdit()
        let fm = FileManager.default
        var done: [Rename] = []
        var skipped = 0
        for preview in previews where preview.isChange {
            let from = dir.appendingPathComponent(preview.original)
            let to = dir.appendingPathComponent(preview.proposed)
            if fm.fileExists(atPath: to.path) { skipped += 1; continue }   // never clobber
            if (try? fm.moveItem(at: from, to: to)) != nil { done.append(Rename(from: from, to: to)) } else { skipped += 1 }
        }
        reload(dir)
        examples = []
        selectedFile = nil
        correctedName = ""
        lastBatch = done
        statusMessage = Voice.applied(done.count, skipped: skipped)
    }

    func undo() {
        let fm = FileManager.default
        var reverted = 0
        for rename in lastBatch.reversed() where !fm.fileExists(atPath: rename.from.path) {
            if (try? fm.moveItem(at: rename.to, to: rename.from)) != nil { reverted += 1 }
        }
        lastBatch = []
        if let dir = directoryURL { reload(dir) }
        statusMessage = Voice.undone(reverted)
    }

    func startOver() {
        examples = []
        selectedFile = nil
        correctedName = ""
        previews = identityPreviews()
        warnings = []
        needsMoreInfo = nil
        statusMessage = Voice.startedOver
    }

    // MARK: - Helpers

    private func reload(_ url: URL) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        files = names.filter { !$0.hasPrefix(".") }.sorted()
        previews = identityPreviews()
        needsMoreInfo = nil
    }

    private func identityPreviews() -> [RenamePreview] {
        files.map { RenamePreview(original: $0, proposed: $0, isConfident: false, note: nil) }
    }

    /// How many previews are flagged (uncertain) — drives the safety footnote.
    var flaggedCount: Int { previews.filter { !$0.isConfident }.count }
}

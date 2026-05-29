import Foundation
import AppKit
import UniformTypeIdentifiers
import RenamrCore

@MainActor
final class RenameModel: ObservableObject {
    @Published var directoryURL: URL?
    @Published private(set) var files: [String] = []
    @Published var selectedFile: String?       // the example "before"
    @Published var correctedName: String = ""   // the example "after"
    @Published private(set) var previews: [RenamePreview] = []
    @Published private(set) var warnings: [String] = []
    @Published private(set) var lastBatch: [Rename] = []
    @Published var statusMessage: String = ""

    struct Rename: Equatable { let from: URL; let to: URL }

    var confidentChangeCount: Int { previews.filter(\.isChange).count }

    // MARK: - Loading a folder

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
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

    func load(_ url: URL) {
        directoryURL = url
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        files = names.filter { !$0.hasPrefix(".") }.sorted()
        selectedFile = nil
        correctedName = ""
        previews = identityPreviews()
        warnings = []
        lastBatch = []
        statusMessage = files.isEmpty ? "No files in this folder." : "\(files.count) files"
    }

    // MARK: - The example -> synthesis loop

    func selectExample(_ name: String) {
        selectedFile = name
        correctedName = name          // seed with the current name; the user edits it
        recompute()
    }

    func recompute() {
        guard let before = selectedFile, !correctedName.isEmpty, correctedName != before else {
            previews = identityPreviews()
            warnings = []
            return
        }
        let result = Renamr.synthesize(examples: [(before, correctedName)], files: files)
        previews = result.previews
        warnings = result.warnings
    }

    // MARK: - Applying / undoing

    func apply() {
        guard let dir = directoryURL else { return }
        let fm = FileManager.default
        var done: [Rename] = []
        var skipped = 0
        for preview in previews where preview.isChange {
            let from = dir.appendingPathComponent(preview.original)
            let to = dir.appendingPathComponent(preview.proposed)
            if fm.fileExists(atPath: to.path) { skipped += 1; continue }   // never clobber
            do {
                try fm.moveItem(at: from, to: to)
                done.append(Rename(from: from, to: to))
            } catch {
                skipped += 1
            }
        }
        reload(dir)
        lastBatch = done
        statusMessage = "Renamed \(done.count) file\(done.count == 1 ? "" : "s")"
            + (skipped > 0 ? " · skipped \(skipped)" : "")
    }

    func undo() {
        let fm = FileManager.default
        var reverted = 0
        for rename in lastBatch.reversed() where !fm.fileExists(atPath: rename.from.path) {
            if (try? fm.moveItem(at: rename.to, to: rename.from)) != nil { reverted += 1 }
        }
        let dir = directoryURL
        lastBatch = []
        if let dir { reload(dir) }
        statusMessage = "Reverted \(reverted) file\(reverted == 1 ? "" : "s")"
    }

    // MARK: - Helpers

    /// Reload the folder listing without wiping the current example/selection.
    private func reload(_ url: URL) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        files = names.filter { !$0.hasPrefix(".") }.sorted()
        if let sel = selectedFile, !files.contains(sel) { selectedFile = nil; correctedName = "" }
        recompute()
    }

    private func identityPreviews() -> [RenamePreview] {
        files.map { RenamePreview(original: $0, proposed: $0, isConfident: false, note: nil) }
    }
}

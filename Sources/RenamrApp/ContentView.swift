import SwiftUI
import UniformTypeIdentifiers
import RenamrCore

struct ContentView: View {
    @EnvironmentObject var model: RenameModel
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if model.hasFolder { mainPanes } else { emptyState }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars").foregroundStyle(.tint)
            Text("Renamr").font(.headline)
            Text("rename by example").font(.caption).foregroundStyle(.secondary)
            if model.hasFolder {
                Button { model.chooseFolder() } label: { Image(systemName: "folder") }
                    .buttonStyle(.borderless).help("Open a different folder")
            }
            Spacer()
            Text(model.statusMessage).font(.callout).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    // MARK: empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wand.and.stars").font(.system(size: 50)).foregroundStyle(.tint.opacity(0.85))
            Text("Show me one. I'll do the rest.").font(.title3.weight(.medium))
            Text("Fix a single filename — Renamr spots the pattern and renames the whole folder.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("Open Folder…") { model.chooseFolder() }.controlSize(.large)
                Button("Use Frontmost Finder Folder") { model.openFrontmostFinderFolder() }.controlSize(.large)
            }
            .padding(.top, 4)
            Label("Tip: right-click files in Finder ▸ Rename by Example", systemImage: "contextualmenu.and.cursorarrow")
                .font(.caption).foregroundStyle(.tertiary).padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(dropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { model.handleDrop($0) }
    }

    // MARK: main

    private var mainPanes: some View {
        HStack(spacing: 0) {
            fileList.frame(width: 290)
            Divider()
            rightPane.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { model.handleDrop($0) }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Files").font(.headline)
                Spacer()
                if !model.examples.isEmpty {
                    Text("learning from \(model.examples.count)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            List(
                model.files,
                id: \.self,
                selection: Binding(get: { model.selectedFile }, set: { if let n = $0 { model.selectExample(n) } })
            ) { name in
                HStack(spacing: 6) {
                    if model.preselected.contains(name) {
                        Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tint)
                    }
                    Text(name).font(.system(.body, design: .monospaced)).lineLimit(1)
                }
            }
        }
    }

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.selectedFile != nil {
                Text(model.examples.count >= 1 ? "Fix another, if I got one wrong" : "Rename this one — I'll learn the pattern")
                    .font(.headline)
                TextField("corrected name", text: $model.correctedName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: model.correctedName) { _ in model.recompute() }
                    .onSubmit { model.recompute() }
            } else {
                Text("Pick a file on the left, then type what it should be called.")
                    .foregroundStyle(.secondary)
            }

            if let prompt = model.needsMoreInfo { disagreementBanner(prompt) }

            if !model.warnings.isEmpty {
                Text(model.warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Text("Preview").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if model.confidentChangeCount > 0 {
                    Text("\(model.confidentChangeCount) will change").font(.caption).foregroundStyle(.secondary)
                }
            }
            previewList
        }
        .padding(12)
    }

    private func disagreementBanner(_ prompt: DisagreementPrompt) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "questionmark.bubble").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Two ways to read that.").font(.callout.weight(.medium))
                Text("For “\(prompt.file)”, did you mean " + prompt.options.prefix(2).map { "“\($0)”" }.joined(separator: " or ") + "?")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Teach me") { model.teachAmbiguousFile() }.controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var previewList: some View {
        List(model.previews) { preview in
            HStack(spacing: 8) {
                Image(systemName: icon(for: preview)).foregroundStyle(tint(for: preview))
                Text(preview.original).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                Text(preview.proposed)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(preview.isChange ? .primary : .secondary).lineLimit(1)
                Spacer()
            }
            .help(preview.note ?? "")
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: 10) {
            if !model.examples.isEmpty || model.selectedFile != nil {
                Button("Start over") { model.startOver() }.controlSize(.regular)
            }
            if !model.lastBatch.isEmpty {
                Button("Undo") { model.undo() }.controlSize(.regular)
            }
            Spacer()
            Button { model.apply() } label: {
                Text(model.confidentChangeCount > 0 ? "Rename \(model.confidentChangeCount) files" : "Rename")
                    .frame(minWidth: 130)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.confidentChangeCount == 0)
        }
        .padding(10)
    }

    private func icon(for p: RenamePreview) -> String {
        if !p.isConfident { return "questionmark.circle" }
        return p.isChange ? "checkmark.circle.fill" : "circle"
    }

    private func tint(for p: RenamePreview) -> Color {
        if !p.isConfident { return .orange }
        return p.isChange ? .green : .secondary
    }
}

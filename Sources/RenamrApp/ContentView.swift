import SwiftUI
import UniformTypeIdentifiers
import RenamrCore

struct ContentView: View {
    @EnvironmentObject var model: RenameModel
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            Group {
                if model.directoryURL == nil {
                    dropZone
                } else {
                    mainPanes
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button("Open Folder…") { model.chooseFolder() }
            if let url = model.directoryURL {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(url.lastPathComponent).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(model.statusMessage).foregroundStyle(.secondary).font(.callout)
        }
        .padding(10)
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars").font(.system(size: 46)).foregroundStyle(.secondary)
            Text("Drop a folder here").font(.title3)
            Text("Then rename one file — the rest follow.").foregroundStyle(.secondary)
            Button("Open Folder…") { model.chooseFolder() }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in model.handleDrop(providers) }
    }

    private var mainPanes: some View {
        HStack(spacing: 0) {
            fileList.frame(width: 280)
            Divider()
            rightPane.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Files").font(.headline).padding(8)
            List(
                model.files,
                id: \.self,
                selection: Binding(
                    get: { model.selectedFile },
                    set: { if let name = $0 { model.selectExample(name) } }
                )
            ) { name in
                Text(name).font(.system(.body, design: .monospaced)).lineLimit(1)
            }
        }
    }

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.selectedFile != nil {
                Text("Rename this one — the rest follow").font(.headline)
                TextField("corrected name", text: $model.correctedName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: model.correctedName) { _ in model.recompute() }
                    .onSubmit { model.recompute() }
            } else {
                Text("Pick a file on the left, then type its corrected name.")
                    .foregroundStyle(.secondary)
            }

            if !model.warnings.isEmpty {
                Text(model.warnings.joined(separator: "\n"))
                    .font(.caption).foregroundStyle(.orange)
            }

            Text("Preview").font(.subheadline).foregroundStyle(.secondary)
            previewList
        }
        .padding(12)
    }

    private var previewList: some View {
        List(model.previews) { preview in
            HStack(spacing: 8) {
                Image(systemName: icon(for: preview))
                    .foregroundStyle(tint(for: preview))
                Text(preview.original)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                Text(preview.proposed)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(preview.isChange ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
            }
            .help(preview.note ?? "")
        }
    }

    private var footer: some View {
        HStack {
            if !model.lastBatch.isEmpty {
                Button("Undo") { model.undo() }
            }
            Spacer()
            Button {
                model.apply()
            } label: {
                Text(model.confidentChangeCount > 0 ? "Rename \(model.confidentChangeCount) files" : "Rename")
                    .frame(minWidth: 120)
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

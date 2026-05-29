import SwiftUI
import UniformTypeIdentifiers
import RenamrCore

struct ContentView: View {
    @EnvironmentObject var model: RenameModel
    @State private var dropTargeted = false
    @FocusState private var editing: Bool

    private var mood: Mascot.Mood {
        if model.needsMoreInfo != nil { return .thinking }
        if model.confidentChangeCount > 0 { return .happy }
        return .idle
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            Group {
                if model.hasFolder { folderView } else { emptyState }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.4)
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { model.handleDrop($0) }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 9) {
            Mascot(mood: mood, size: 26)
            Text("Renamr").font(.headline)
            Text(Voice.tagline).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(model.statusMessage)
                .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                .animation(.default, value: model.statusMessage)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    // MARK: empty state — compact, centered, teaches at a glance

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Mascot(mood: .idle, size: 104)
            Text(Voice.emptyTitle)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text(Voice.emptySubtitle)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
                .padding(.top, 6)

            Button("Open a Folder…") { model.chooseFolder() }
                .buttonStyle(.borderedProminent).tint(Brand.green).controlSize(.large)
                .padding(.top, 22)

            Button { model.openFrontmostFinderFolder() } label: {
                Label("Use the folder open in Finder", systemImage: "macwindow")
            }
            .buttonStyle(.plain).foregroundStyle(Brand.green).font(.callout)
            .padding(.top, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(dropTargeted ? Brand.green.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: folder view — path bar + folders + inline-editable files

    private var folderView: some View {
        VStack(spacing: 0) {
            pathBar
            Divider().opacity(0.4)

            if let prompt = model.needsMoreInfo { disagreementBanner(prompt).padding([.horizontal, .top], 12) }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !model.folders.isEmpty {
                        sectionHeader("Folders")
                        ForEach(model.folders, id: \.self) { folder in
                            FolderRow(name: folder) { model.enter(folder); editing = false }
                        }
                    }
                    if !model.previews.isEmpty {
                        sectionHeader(model.selectedFile == nil ? "Files — click one and type its new name" : "Type the new name — the rest follow")
                        ForEach(model.previews) { preview in
                            FileRow(
                                preview: preview,
                                isSelected: preview.original == model.selectedFile,
                                correctedName: $model.correctedName,
                                editing: $editing,
                                onTap: { model.selectExample(preview.original); editing = true },
                                onEdit: { model.recompute() }
                            )
                        }
                    } else if model.folders.isEmpty {
                        Text("This folder is empty.").font(.callout).foregroundStyle(.secondary).padding(12)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .animation(.easeOut(duration: 0.16), value: model.previews)
            }

            if model.flaggedCount > 0 {
                Label(Voice.safety, systemImage: "leaf")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.bottom, 8)
            }
        }
    }

    private var pathBar: some View {
        HStack(spacing: 8) {
            Button { model.goUp(); editing = false } label: {
                Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless).help("Up to the enclosing folder")
            Image(systemName: "folder.fill").foregroundStyle(Brand.green).font(.system(size: 12))
            Text(model.directoryURL?.lastPathComponent ?? "")
                .font(.system(size: 12, weight: .medium)).lineLimit(1)
            Spacer()
            if model.examples.count >= 1 {
                Label("learning from \(model.examples.count)", systemImage: "leaf.fill")
                    .font(.caption2).foregroundStyle(Brand.green)
            }
            Button("Change…") { model.chooseFolder() }.controlSize(.small).buttonStyle(.borderless)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold)).textCase(.uppercase)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
    }

    private func disagreementBanner(_ prompt: DisagreementPrompt) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Mascot(mood: .thinking, size: 30, animated: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(Voice.ambiguityTitle).font(.callout.weight(.semibold))
                Text("For “\(prompt.file)”, did you mean " + prompt.options.prefix(2).map { "“\($0)”" }.joined(separator: " or ") + "?")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Show me") { model.teachAmbiguousFile(); editing = true }.controlSize(.small)
        }
        .padding(11)
        .background(Brand.blossom.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: 10) {
            if !model.examples.isEmpty || model.selectedFile != nil {
                Button("Start over") { model.startOver(); editing = false }
            }
            if !model.lastBatch.isEmpty {
                Button("Undo") { model.undo() }
            }
            Spacer()
            Button { model.apply(); editing = false } label: {
                Text(model.confidentChangeCount > 0 ? "Rename \(model.confidentChangeCount) files" : "Rename")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent).tint(Brand.green)
            .keyboardShortcut(.defaultAction)
            .disabled(model.confidentChangeCount == 0)
        }
        .padding(12)
    }
}

// MARK: - Rows

private struct FolderRow: View {
    let name: String
    let onOpen: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "folder.fill").foregroundStyle(Brand.green).font(.system(size: 13)).frame(width: 16)
            Text(name).font(.system(.body)).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7).fill(hover ? Brand.green.opacity(0.10) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onOpen)
    }
}

private struct FileRow: View {
    let preview: RenamePreview
    let isSelected: Bool
    @Binding var correctedName: String
    @FocusState.Binding var editing: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 12)).frame(width: 16)

            if isSelected {
                TextField("new name", text: $correctedName)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($editing)
                    .onChange(of: correctedName) { _ in onEdit() }
                    .onSubmit { onEdit() }
            } else {
                Text(preview.original)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(preview.isConfident ? .primary : .secondary)
                    .lineLimit(1)
                if preview.isChange {
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                    Text(preview.proposed)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Brand.green).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Brand.green.opacity(0.16) : (hover ? Brand.green.opacity(0.06) : .clear))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { onTap() }
    }

    private var icon: String {
        if isSelected { return "pencil.circle.fill" }
        if !preview.isConfident { return "circle.dashed" }
        return preview.isChange ? "checkmark.circle.fill" : "circle"
    }

    private var tint: Color {
        if isSelected { return Brand.green }
        if !preview.isConfident { return .secondary.opacity(0.6) }
        return preview.isChange ? Brand.green : .secondary.opacity(0.4)
    }
}

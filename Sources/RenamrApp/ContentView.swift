import SwiftUI
import UniformTypeIdentifiers
import RenamrCore

struct ContentView: View {
    @EnvironmentObject var model: RenameModel
    @State private var dropTargeted = false
    @State private var pulse = false
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            Group {
                if model.hasFolder { fileList } else { emptyState }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.5)
            footer
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { model.handleDrop($0) }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.gradient)
            Text("Renamr").font(.headline)
            Text(Voice.tagline).font(.caption).foregroundStyle(.secondary)
            if model.hasFolder {
                Button { model.chooseFolder() } label: { Image(systemName: "folder") }
                    .buttonStyle(.borderless).help("Open a different folder")
                if model.directoryURL != nil {
                    Text(model.directoryURL!.lastPathComponent).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            Text(model.statusMessage).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                .animation(.default, value: model.statusMessage)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Brand.gradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: Brand.accent.opacity(pulse ? 0.55 : 0.3), radius: pulse ? 26 : 16)
                    .scaleEffect(pulse ? 1.03 : 1.0)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .onAppear { withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { pulse = true } }

            VStack(spacing: 6) {
                Text(Voice.emptyTitle).font(.title2.weight(.semibold))
                Text(Voice.emptySubtitle)
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 420)
            }

            HStack(spacing: 10) {
                Button("Open Folder…") { model.chooseFolder() }
                    .buttonStyle(.borderedProminent).tint(Brand.accent).controlSize(.large)
                Button("Use Frontmost Finder Folder") { model.openFrontmostFinderFolder() }
                    .controlSize(.large)
            }
            .padding(.top, 2)

            Label(Voice.finderTip, systemImage: "contextualmenu.and.cursorarrow")
                .font(.caption).foregroundStyle(.tertiary).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(dropTargeted ? Brand.accent.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: the unified, inline-editable list

    private var fileList: some View {
        VStack(spacing: 0) {
            if let prompt = model.needsMoreInfo { disagreementBanner(prompt).padding([.horizontal, .top], 12) }

            HStack {
                Text(model.selectedFile == nil ? "Click a file and type its new name" : "Type the new name — the rest follow")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                if model.examples.count >= 1 {
                    Label("learning from \(model.examples.count)", systemImage: "brain")
                        .font(.caption2).foregroundStyle(Brand.accent)
                }
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 2) {
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
                }
                .padding(.horizontal, 10).padding(.bottom, 8)
                .animation(.easeOut(duration: 0.18), value: model.previews)
            }

            if model.flaggedCount > 0 {
                Label(Voice.safety, systemImage: "lock.shield")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.bottom, 8)
            }
        }
    }

    private func disagreementBanner(_ prompt: DisagreementPrompt) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "questionmark.bubble.fill").foregroundStyle(Brand.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(Voice.ambiguityTitle).font(.callout.weight(.semibold))
                Text("For “\(prompt.file)”, did you mean " + prompt.options.prefix(2).map { "“\($0)”" }.joined(separator: " or ") + "?")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Teach me") { model.teachAmbiguousFile(); editing = true }.controlSize(.small)
        }
        .padding(11)
        .background(Brand.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
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
            .buttonStyle(.borderedProminent).tint(Brand.accent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.confidentChangeCount == 0)
        }
        .padding(12)
    }
}

/// One row: the original name, or an inline editor when it's the file you're
/// teaching with. Changed rows show "→ newname" live.
private struct FileRow: View {
    let preview: RenamePreview
    let isSelected: Bool
    @Binding var correctedName: String
    @FocusState.Binding var editing: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 12)).frame(width: 15)

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
                        .foregroundStyle(Brand.accent)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Brand.accent.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var icon: String {
        if isSelected { return "pencil.circle.fill" }
        if !preview.isConfident { return "questionmark.circle" }
        return preview.isChange ? "checkmark.circle.fill" : "circle"
    }

    private var tint: Color {
        if isSelected { return Brand.accent }
        if !preview.isConfident { return .orange }
        return preview.isChange ? .green : .secondary.opacity(0.5)
    }
}

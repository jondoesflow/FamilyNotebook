import SwiftUI
import PhotosUI
import CoreData
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @ObservedObject var note: Note

    var body: some View {
        PinGate(lockID: note.uuid?.uuidString ?? "", pinHash: note.pinHash, title: note.displayTitle) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inkSecondary)
                .padding(24)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } content: {
            NoteEditorContent(note: note)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NoteEditorContent: View {
    @ObservedObject var note: Note
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var persistence: Persistence

    @State private var title = ""
    @State private var body_ = NSAttributedString(string: "", attributes: Typography.typing)
    @State private var isTyping = false
    @State private var showSketch = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var viewingPhoto: Attachment?
    @State private var saveTask: Task<Void, Never>?
    @State private var loadedStamp: Date?
    @State private var changedThisSession = false
    @State private var showMove = false
    @State private var showVersions = false
    @State private var showPinSetup = false
    @FocusState private var titleFocused: Bool

    private var canEdit: Bool { persistence.canEdit(note) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                meta
                TextField("Title", text: $title, axis: .vertical)
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                    .focused($titleFocused)
                    .submitLabel(.next)
                    .disabled(!canEdit)
                    .onChange(of: title) { _, _ in scheduleSave() }

                ZStack(alignment: .topLeading) {
                    if body_.length == 0 {
                        Text(placeholder)
                            .font(.system(size: Typography.bodySize, design: .serif))
                            .foregroundStyle(Theme.inkTertiary)
                            .allowsHitTesting(false)
                    }
                    RichTextEditor(text: $body_, isEditable: canEdit, onInsert: { action in
                        switch action {
                        case .sketch: showSketch = true
                        case .photo: showPhotoPicker = true
                        }
                    }, onFocusChange: { focused in
                        isTyping = focused
                        if !focused { saveNow() }
                    })
                }
                .onChange(of: body_) { _, _ in scheduleSave() }

                if !note.sortedAttachments.isEmpty { photos }

                if let data = note.drawing, note.hasDrawing {
                    Button { showSketch = true } label: {
                        SketchPreview(data: data).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canEdit)
                }

                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 120)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .paperBackground()
        .toolbar { toolbar }
        .sheet(isPresented: $showSketch) {
            SketchEditor(data: Binding(get: { note.drawing }, set: { note.drawing = $0; note.touch(); changedThisSession = true; persistence.save() }))
        }
        .sheet(isPresented: $showMove) {
            MoveNoteSheet(note: note) { moved in
                saveNow()
                let wasCopied = moved != note
                persistence.save()
                if wasCopied { dismiss() }
            }
        }
        .sheet(isPresented: $showVersions) {
            VersionHistoryView(note: note) { load() }
        }
        .sheet(isPresented: $showPinSetup) {
            PinSetupSheet(title: "Protect “\(note.displayTitle)”", lockID: note.uuid?.uuidString ?? "") { hash in
                note.pinHash = hash
                persistence.save()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
        .fullScreenCover(item: $viewingPhoto) { att in PhotoViewer(attachment: att) }
        .onAppear {
            load()
            if (note.title ?? "").isEmpty && (note.plainText ?? "").isEmpty && canEdit {
                titleFocused = note.notebook?.notebookKind != .journal
            }
        }
        .onDisappear {
            saveNow()
            if changedThisSession, !note.isDeleted, note.managedObjectContext != nil {
                note.snapshot()
                persistence.save()
            }
        }
        .onChange(of: note.updatedAt) { _, stamp in
            // Pull in the other person's edits if we're not mid-sentence.
            guard !isTyping, !titleFocused, stamp != loadedStamp, note.lastEditor != People.me else { return }
            load()
        }
    }

    private var placeholder: String {
        if note.notebook?.notebookKind == .journal { return Journal.promptOfTheDay }
        return "Start writing…"
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if let nb = note.notebook {
                Text(nb.displayTitle)
                Text("·")
            }
            if let entry = note.entryDate {
                Text(entry.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            } else {
                Text("\(note.readingMinutes) min read")
            }
            if note.pinHash != nil {
                Image(systemName: "lock.fill").font(.caption)
            }
            Spacer()
            if let nb = note.notebook, persistence.isShared(nb) {
                AvatarPair(size: 26)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.inkSecondary)
        .padding(.top, 8)
    }

    private var photos: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(note.sortedAttachments, id: \.objectID) { att in
                if let data = att.imageData, let img = UIImage(data: data) {
                    Button { viewingPhoto = att } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Image(uiImage: img).resizable().scaledToFill())
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        if canEdit {
                            Button("Remove photo", systemImage: "trash", role: .destructive) {
                                persistence.viewContext.delete(att)
                                note.touch()
                                persistence.save()
                            }
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let editor = note.lastEditor {
                Avatar(name: editor, size: 20)
                Text("\(editor == People.me ? "You" : editor) edited \(note.updatedAt?.relativeShort ?? "")")
            }
            Spacer()
        }
        .font(.footnote)
        .foregroundStyle(Theme.inkTertiary)
        .padding(.top, 24)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ShareLink(item: note.shareText, preview: SharePreview(note.displayTitle)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                if canEdit {
                    Button(note.isPinned ? "Unpin" : "Pin to the top", systemImage: note.isPinned ? "pin.slash" : "pin") {
                        note.isPinned.toggle()
                        persistence.save()
                    }
                    Button("Move to another notebook", systemImage: "folder") { saveNow(); showMove = true }
                    if note.pinHash == nil {
                        Button("Protect with PIN", systemImage: "lock") { showPinSetup = true }
                    } else {
                        Button("Remove PIN", systemImage: "lock.open") { note.pinHash = nil; persistence.save() }
                    }
                }
                Button("Version history", systemImage: "clock.arrow.circlepath") {
                    saveNow()
                    if changedThisSession { note.snapshot(); persistence.save(); changedThisSession = false }
                    showVersions = true
                }
                ShareLink(item: MarkdownDocument(name: note.displayTitle, text: note.markdown),
                          preview: SharePreview("\(note.displayTitle).md")) {
                    Label("Export to Markdown", systemImage: "arrow.down.doc")
                }
                if canEdit {
                    Divider()
                    Button("Move to Trash", systemImage: "trash", role: .destructive) {
                        saveNow()
                        note.trashedAt = .now
                        persistence.save()
                        dismiss()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: - Load & save

    private func load() {
        title = note.title ?? ""
        body_ = RichTextCodec.decode(note.body)
        loadedStamp = note.updatedAt
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        guard canEdit, !note.isDeleted, note.managedObjectContext != nil else { return }
        let newBody = RichTextCodec.encode(body_)
        guard note.title != title || note.body != newBody else { return }
        note.title = title
        note.body = newBody
        note.plainText = body_.string
        note.touch()
        loadedStamp = note.updatedAt
        changedThisSession = true
        persistence.save()
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = ImageTools.compressed(data) else { continue }
            await MainActor.run {
                let att = Attachment(context: persistence.viewContext)
                persistence.assign(att, alongside: note)
                att.uuid = UUID()
                att.createdAt = .now
                att.imageData = jpeg
                att.note = note
            }
        }
        await MainActor.run {
            note.touch()
            changedThisSession = true
            persistence.save()
            photoItems = []
        }
    }
}

extension Note {
    var shareText: String {
        let body = (plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return title?.isEmpty == false ? "\(displayTitle)\n\n\(body)" : body
    }
}

extension UTType {
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}

struct MarkdownDocument: Transferable {
    var name: String
    var text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .markdownText) { Data($0.text.utf8) }
            .suggestedFileName { $0.name + ".md" }
    }
}

// MARK: - Move

struct MoveNoteSheet: View {
    @ObservedObject var note: Note
    var onMoved: (Note) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var persistence: Persistence
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "isArchived", ascending: true), NSSortDescriptor(key: "title", ascending: true)], animation: .default)
    private var notebooks: FetchedResults<Notebook>

    var body: some View {
        NavigationStack {
            List {
                ForEach(notebooks.filter { $0 != note.notebook && persistence.canEdit($0) }) { nb in
                    Button {
                        let moved = note.move(to: nb)
                        onMoved(moved)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            NotebookCover(cover: nb.cover, photo: nb.coverPhoto).frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nb.displayTitle).font(Theme.serif(.headline, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(nb.notebookKind.name + (nb.isArchived ? " · On the shelf" : ""))
                                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer()
                            if persistence.isShared(nb) { AvatarPair(size: 20) }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Versions

struct VersionHistoryView: View {
    @ObservedObject var note: Note
    var onRestore: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var persistence: Persistence
    @State private var previewing: NoteVersion?

    var body: some View {
        NavigationStack {
            List {
                if note.sortedVersions.isEmpty {
                    ContentUnavailableView("No versions yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Each time you finish editing, the note remembers how it was."))
                        .listRowBackground(Color.clear)
                }
                ForEach(Array(note.sortedVersions.enumerated()), id: \.element.objectID) { idx, v in
                    Button { previewing = v } label: {
                        HStack(spacing: 12) {
                            Avatar(name: v.author, size: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(v.createdAt?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()) ?? "")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    if idx == 0 { Chip(text: "Latest") }
                                }
                                Text("\(v.author ?? "Someone") · \(String((v.plainText ?? "").prefix(70)).replacingOccurrences(of: "\n", with: " "))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("Version history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $previewing) { v in
                VersionPreview(version: v, canRestore: persistence.canEdit(note)) {
                    note.restore(v)
                    persistence.save()
                    onRestore()
                    dismiss()
                }
            }
        }
    }
}

private struct VersionPreview: View {
    let version: NoteVersion
    var canRestore: Bool
    var restore: () -> Void
    @State private var text = NSAttributedString()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Avatar(name: version.author, size: 22)
                    Text("\(version.author ?? "") · \(version.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                Text((version.title ?? "").isEmpty ? "Untitled" : version.title ?? "")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                RichTextEditor(text: $text, isEditable: false)
            }
            .padding(24)
        }
        .paperBackground()
        .safeAreaInset(edge: .bottom) {
            if canRestore {
                Button("Restore this version", action: restore)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .onAppear { text = RichTextCodec.decode(version.body) }
    }
}

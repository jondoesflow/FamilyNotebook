import SwiftUI
import PhotosUI
import CoreData

struct NoteEditorView: View {
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
    @FocusState private var titleFocused: Bool

    private var canEdit: Bool { persistence.canEdit(note) }
    private var tint: Color { note.notebook?.notebookKind.tint ?? Theme.accent }

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
                    RichTextEditor(text: $body_, isEditable: canEdit) { focused in
                        isTyping = focused
                        if !focused { saveNow() }
                    }
                }
                .onChange(of: body_) { _, _ in scheduleSave() }

                if !note.sortedAttachments.isEmpty { photos }

                if let data = note.drawing, note.hasDrawing {
                    Button { showSketch = true } label: {
                        SketchPreview(data: data)
                            .padding(.vertical, 8)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showSketch) {
            SketchEditor(data: Binding(get: { note.drawing }, set: { note.drawing = $0; note.touch(); persistence.save() }))
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
        .fullScreenCover(item: $viewingPhoto) { att in PhotoViewer(attachment: att) }
        .onAppear(perform: load)
        .onDisappear(perform: saveNow)
        .onChange(of: note.updatedAt) { _, stamp in
            // Pull in the other person's edits if we're not mid-sentence.
            guard !isTyping, !titleFocused, stamp != loadedStamp, note.lastEditor != People.me else { return }
            load()
        }
        .onAppear {
            if (note.title ?? "").isEmpty && (note.plainText ?? "").isEmpty && canEdit {
                titleFocused = note.notebook?.notebookKind != .journal
            }
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
        let atts = note.sortedAttachments
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(atts, id: \.objectID) { att in
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
        ToolbarItemGroup(placement: .topBarTrailing) {
            if canEdit {
                Menu {
                    Button("Photo", systemImage: "photo.on.rectangle") { showPhotoPicker = true }
                    Button(note.hasDrawing ? "Edit sketch" : "Sketch", systemImage: "pencil.tip.crop.circle") { showSketch = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
            Menu {
                if canEdit {
                    Button(note.isPinned ? "Unpin" : "Pin to top", systemImage: note.isPinned ? "pin.slash" : "pin") {
                        note.isPinned.toggle()
                        persistence.save()
                    }
                }
                ShareLink(item: note.markdown, preview: SharePreview(note.displayTitle)) {
                    Label("Export as Markdown", systemImage: "square.and.arrow.up")
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
        let newPlain = body_.string
        guard note.title != title || note.body != newBody else { return }
        note.title = title
        note.body = newBody
        note.plainText = newPlain
        note.touch()
        loadedStamp = note.updatedAt
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
            persistence.save()
            photoItems = []
        }
    }
}

enum ImageTools {
    /// Downsizes and re-encodes, which also strips location and other metadata.
    static func compressed(_ data: Data, maxDimension: CGFloat = 2048) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

struct PhotoViewer: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let data = attachment.imageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { scale = max(1, $0.magnification) }
                        .onEnded { _ in withAnimation(.spring) { scale = 1 } })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
        .gesture(DragGesture().onEnded { if $0.translation.height > 80 { dismiss() } })
    }
}

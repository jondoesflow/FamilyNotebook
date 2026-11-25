import SwiftUI
import CoreData

struct NotebookView: View {
    @ObservedObject var notebook: Notebook
    @EnvironmentObject private var persistence: Persistence
    @State private var editing = false
    @State private var sharingError: String?

    var body: some View {
        Group {
            switch notebook.notebookKind {
            case .notes: NotesListView(notebook: notebook)
            case .journal: JournalView(notebook: notebook)
            case .trip: TripView(notebook: notebook)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        do { try await CloudSharing.present(for: notebook, persistence: persistence) }
                        catch { sharingError = error.localizedDescription }
                    }
                } label: {
                    if persistence.isShared(notebook) {
                        AvatarPair(size: 24)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
                .accessibilityLabel("Share")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if persistence.canEdit(notebook) {
                        Button("Edit cover & title", systemImage: "paintpalette") { editing = true }
                    }
                    ShareLink(item: notebookMarkdown, preview: SharePreview(notebook.displayTitle)) {
                        Label("Export as Markdown", systemImage: "square.and.arrow.up")
                    }
                    Button(notebook.isArchived ? "Take off the shelf" : "Put on the shelf", systemImage: "books.vertical") {
                        notebook.isArchived.toggle()
                        persistence.save()
                    }
                } label: { Image(systemName: "ellipsis") }
            }
        }
        .sheet(isPresented: $editing) { NotebookFormView(notebook: notebook) }
        .alert("Couldn't share", isPresented: Binding(get: { sharingError != nil }, set: { if !$0 { sharingError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text((sharingError ?? "") + "\n\nMake sure you're signed in to iCloud in Settings.")
        }
    }

    private var notebookMarkdown: String {
        let notes = notebook.liveNotes.sorted { ($0.entryDate ?? $0.createdAt ?? .distantPast) < ($1.entryDate ?? $1.createdAt ?? .distantPast) }
        return "# \(notebook.displayTitle)\n\n" + notes.map { $0.markdown.replacingOccurrences(of: "\n# ", with: "\n## ") }
            .joined(separator: "\n\n---\n\n")
    }
}

/// The header shared by every kind of notebook: a strip of the cover art fading into the page.
struct NotebookBanner: View {
    @ObservedObject var notebook: Notebook
    var subtitle: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            NotebookCover(style: notebook.cover, photo: notebook.coverPhoto)
                .frame(width: 84)
            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.notebookKind.name.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(notebook.notebookKind.tint)
                Text(notebook.displayTitle)
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }
}

struct NotesListView: View {
    @ObservedObject var notebook: Notebook
    @EnvironmentObject private var persistence: Persistence
    @FetchRequest private var notes: FetchedResults<Note>
    @State private var openNote: Note?

    init(notebook: Notebook) {
        self.notebook = notebook
        _notes = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "isPinned", ascending: false), NSSortDescriptor(key: "updatedAt", ascending: false)],
                              predicate: NSPredicate(format: "notebook == %@ AND trashedAt == nil", notebook),
                              animation: .spring)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NotebookBanner(notebook: notebook, subtitle: notebook.subtitle)
                if notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.inkTertiary)
                        Text("A blank page").font(Theme.display(22)).foregroundStyle(Theme.ink)
                        Text("Nothing in the way. Tap below to start.")
                            .font(Theme.serif(.body)).foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                }
                LazyVStack(spacing: 12) {
                    ForEach(notes) { note in
                        NavigationLink(value: Route.note(note)) {
                            NoteRow(note: note)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button(note.isPinned ? "Unpin" : "Pin to top", systemImage: note.isPinned ? "pin.slash" : "pin") {
                                note.isPinned.toggle(); persistence.save()
                            }
                            Button("Move to Trash", systemImage: "trash", role: .destructive) {
                                note.trashedAt = .now; persistence.save()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .bottom) {
            if persistence.canEdit(notebook) {
                FloatingNewButton(title: "New note", tint: Theme.accent) {
                    openNote = Note.create(in: notebook)
                    persistence.save()
                }
            }
        }
        .navigationDestination(item: $openNote) { NoteEditorView(note: $0) }
    }
}

struct FloatingNewButton: View {
    var title: String
    var tint: Color
    var action: () -> Void
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Label(title, systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 15)
                .background(tint, in: Capsule())
                .shadow(color: tint.opacity(0.35), radius: 14, y: 8)
        }
        .buttonStyle(PressableStyle())
        .padding(.bottom, 20)
    }
}

struct NoteRow: View {
    @ObservedObject var note: Note
    var showNotebook = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Theme.accent)
                    }
                    if showNotebook, let nb = note.notebook {
                        Text(nb.displayTitle.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(nb.notebookKind.tint)
                    }
                }
                Text(note.displayTitle)
                    .font(Theme.serif(.title3, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !note.excerpt.isEmpty {
                    Text(note.excerpt)
                        .font(Theme.serif(.subheadline))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    Avatar(name: note.lastEditor, size: 16)
                    Text(note.updatedAt?.relativeShort ?? "")
                    if note.hasDrawing { Image(systemName: "scribble") }
                    if (note.attachments?.count ?? 0) > 0 { Image(systemName: "photo") }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkTertiary)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if let first = note.sortedAttachments.first?.imageData, let img = UIImage(data: first) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18)
    }
}

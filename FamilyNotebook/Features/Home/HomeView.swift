import SwiftUI
import CoreData

enum Route: Hashable {
    case notebook(Notebook)
    case note(Note)
    case settings
}

struct HomeView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var persistence: Persistence
    @AppStorage("me") private var me: String = ""

    @FetchRequest(sortDescriptors: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt, order: .reverse)],
                  predicate: NSPredicate(format: "isArchived == NO"), animation: .spring)
    private var notebooks: FetchedResults<Notebook>

    @FetchRequest(sortDescriptors: [SortDescriptor(\.title)],
                  predicate: NSPredicate(format: "isArchived == YES"), animation: .spring)
    private var archived: FetchedResults<Notebook>

    @FetchRequest(sortDescriptors: [SortDescriptor(\.updatedAt, order: .reverse)],
                  predicate: NSPredicate(format: "isPinned == YES AND trashedAt == nil"), animation: .spring)
    private var pinned: FetchedResults<Note>

    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var showNew = false
    @State private var editing: Notebook?
    @State private var deleting: Notebook?
    @State private var pinTarget: Notebook?
    @Namespace private var zoom

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 22, alignment: .top)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 34) {
                        header
                        if !pinned.isEmpty { pinnedSection }
                        shelf
                        if !archived.isEmpty { archiveShelf }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
                } else {
                    SearchResults(query: query) { path.append(Route.note($0)) }
                        .padding(.horizontal, 20)
                }
            }
            .scrollIndicators(.hidden)
            .paperBackground()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search everything")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(Route.settings) } label: { Avatar(name: me, size: 30) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New notebook")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .notebook(let nb):
                    LockGate(notebook: nb) { NotebookView(notebook: nb) }
                        .navigationTransition(.zoom(sourceID: nb.objectID, in: zoom))
                case .note(let note):
                    NoteEditorView(note: note)
                case .settings:
                    SettingsView()
                }
            }
            .sheet(isPresented: $showNew) {
                NotebookFormView(notebook: nil) { nb in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { path.append(Route.notebook(nb)) }
                }
            }
            .sheet(item: $editing) { nb in NotebookFormView(notebook: nb) }
            .sheet(item: $pinTarget) { nb in
                PinSetupSheet(title: "Protect “\(nb.displayTitle)”", lockID: nb.uuid?.uuidString ?? "") { hash in
                    nb.pinHash = hash
                    persistence.save()
                }
            }
            .confirmationDialog("Delete this notebook and everything in it?",
                                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Delete notebook", role: .destructive) {
                    if let nb = deleting { context.delete(nb); persistence.save() }
                    deleting = nil
                }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            Text(greeting)
                .font(Theme.display(36))
                .foregroundStyle(Theme.ink)
        }
        .padding(.top, 4)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return "\(part), \(me)"
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pinned")
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(pinned) { note in
                        Button { path.append(Route.note(note)) } label: {
                            PinnedNoteCard(note: note)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Your notebooks", trailing: notebooks.isEmpty ? nil : "\(notebooks.count)")
            if notebooks.isEmpty {
                EmptyShelf { showNew = true }
            } else {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(notebooks) { nb in
                        Button { path.append(Route.notebook(nb)) } label: {
                            NotebookTile(notebook: nb)
                                .matchedTransitionSource(id: nb.objectID, in: zoom)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu { menu(for: nb) }
                    }
                    Button { showNew = true } label: { NewNotebookTile() }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for nb: Notebook) -> some View {
        let canEdit = persistence.canEdit(nb)
        Button("Share with \(People.partner)", systemImage: "person.2") {
            Task { try? await CloudSharing.present(for: nb, persistence: persistence) }
        }
        if canEdit {
            Button("Edit cover & title", systemImage: "paintpalette") { editing = nb }
        }
        Button("Move to front", systemImage: "arrow.up.to.line") {
            nb.sortIndex = (notebooks.map(\.sortIndex).min() ?? 0) - 1
            persistence.save()
        }
        if !nb.isLocked && canEdit {
            Button("Protect with PIN", systemImage: "lock") { pinTarget = nb }
        }
        Button("Put on the shelf", systemImage: "books.vertical") {
            withAnimation(.spring) { nb.isArchived = true; persistence.save() }
        }
        if canEdit && !persistence.isParticipantCopy(nb) {
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = nb }
        }
    }

    private var archiveShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "On the shelf", trailing: "\(archived.count)")
            Text("Notebooks you've finished with for now. Tap one to open it.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(archived.enumerated()), id: \.element.objectID) { idx, nb in
                            Button { path.append(Route.notebook(nb)) } label: {
                                NotebookSpine(cover: nb.cover, photo: nb.coverPhoto, title: nb.displayTitle,
                                              height: 132 + CGFloat((idx * 37) % 5) * 6)
                            }
                            .buttonStyle(PressableStyle())
                            .contextMenu {
                                Button("Take off the shelf", systemImage: "arrow.up.bin") {
                                    withAnimation(.spring) { nb.isArchived = false; persistence.save() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    WoodenShelf()
                }
                .frame(minWidth: 320)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Tiles

struct NotebookTile: View {
    @ObservedObject var notebook: Notebook
    @EnvironmentObject private var persistence: Persistence

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotebookCover(cover: notebook.cover, photo: notebook.coverPhoto)
                .overlay(alignment: .topTrailing) { badges.padding(10) }
                .overlay(alignment: .bottomLeading) {
                    if notebook.notebookKind != .notes {
                        Image(systemName: notebook.notebookKind.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.28), in: Circle())
                            .padding(10)
                            .padding(.leading, 6)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.displayTitle)
                    .font(Theme.serif(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(notebook.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.leading, 4)
        }
        .id(persistence.shareRevision)
    }

    @ViewBuilder private var badges: some View {
        HStack(spacing: 6) {
            if notebook.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.3), in: Circle())
            }
            if persistence.isShared(notebook) {
                AvatarPair(size: 20)
            }
        }
    }
}

struct NewNotebookTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.inkTertiary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .aspectRatio(0.72, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "plus").font(.title2.weight(.medium))
                        Text("New notebook").font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Theme.inkSecondary)
                }
            Text(" ").font(Theme.serif(.headline))
        }
    }
}

struct PinnedNoteCard: View {
    @ObservedObject var note: Note
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Theme.accent)
                Text(note.notebook?.displayTitle ?? "")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
            Text(note.displayTitle)
                .font(Theme.serif(.headline, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(note.excerpt)
                .font(Theme.serif(.subheadline))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 220, height: 150, alignment: .topLeading)
        .card(radius: 18)
    }
}

struct EmptyShelf: View {
    var action: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(Array(["camper", "coffee", "night-peaks", "lemons", "monstera"].map(Cover.named).enumerated()), id: \.offset) { i, s in
                    NotebookCover(cover: s)
                        .frame(width: i == 2 ? 104 : 92)
                        .rotationEffect(.degrees(Double(i - 2) * 9))
                        .offset(x: CGFloat(i - 2) * 46, y: abs(CGFloat(i - 2)) * 8)
                        .zIndex(i == 2 ? 1 : 0)
                }
            }
            .frame(height: 170)
            Text("A notebook for everything")
                .font(Theme.display(24))
                .foregroundStyle(Theme.ink)
            Text("Ideas, recipes, a shared journal, the next trip. Give each one its own cover.")
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Start your first notebook", action: action)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 320)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

struct WoodenShelf: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: 0xD9B98C), Color(hex: 0xC09062)], startPoint: .top, endPoint: .bottom)
                .frame(height: 10)
            Color(hex: 0x9A6E45).frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 5)
    }
}

// MARK: - Search

struct SearchResults: View {
    @FetchRequest private var results: FetchedResults<Note>
    var open: (Note) -> Void

    init(query: String, open: @escaping (Note) -> Void) {
        self.open = open
        _results = FetchRequest(sortDescriptors: [SortDescriptor(\.updatedAt, order: .reverse)],
                                predicate: NSPredicate(format: "trashedAt == nil AND (title CONTAINS[cd] %@ OR plainText CONTAINS[cd] %@)", query, query))
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if results.isEmpty {
                ContentUnavailableView.search
                    .padding(.top, 60)
            }
            ForEach(results) { note in
                Button { open(note) } label: { NoteRow(note: note, showNotebook: true) }
                    .buttonStyle(PressableStyle())
            }
        }
        .padding(.vertical, 12)
    }
}

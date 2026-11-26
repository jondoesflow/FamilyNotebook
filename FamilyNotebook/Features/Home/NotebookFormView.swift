import SwiftUI
import PhotosUI

/// Create a notebook (pick what it is and its cover) or edit an existing one.
struct NotebookFormView: View {
    var notebook: Notebook?
    var onCreate: (Notebook) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var persistence: Persistence

    @State private var title = ""
    @State private var kind: NotebookKind = .notes
    @State private var cover: Cover = .named("night-peaks")
    @State private var photo: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var tripStart = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
    @State private var tripEnd = Calendar.current.date(byAdding: .day, value: 34, to: .now)!
    @State private var hasDates = true
    @State private var currency = Locale.current.currency?.identifier ?? "GBP"
    @FocusState private var titleFocused: Bool

    private var isNew: Bool { notebook == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    NotebookCover(cover: cover, photo: photo, title: title.isEmpty ? nil : title, showLabel: !title.isEmpty)
                        .frame(width: 150)
                        .rotation3DEffect(.degrees(-8), axis: (x: 0, y: 1, z: 0))
                        .padding(.top, 12)
                        .animation(.spring(duration: 0.4), value: cover)

                    TextField(kind == .trip ? "Where to?" : "Name your notebook", text: $title)
                        .font(Theme.display(26))
                        .multilineTextAlignment(.center)
                        .focused($titleFocused)
                        .submitLabel(.done)

                    if isNew { kindPicker }

                    if kind == .trip { tripFields }

                    coverPicker
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .paperBackground()
            .navigationTitle(isNew ? "New notebook" : "Edit notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Create" : "Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let small = ImageTools.compressed(data, maxDimension: 1200) {
                        photo = small
                        cover = .photo
                    }
                }
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type").font(.subheadline.weight(.medium)).foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 8) {
                ForEach(NotebookKind.allCases) { k in
                    Button {
                        withAnimation(.snappy) { kind = k }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Label(k.name, systemImage: k.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(kind == k ? .white : Theme.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(kind == k ? k.tint : .clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(kind == k ? .clear : Theme.hairline, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(kind.blurb).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tripFields: some View {
        VStack(spacing: 0) {
            Toggle("Dates", isOn: $hasDates.animation())
                .padding(14)
            if hasDates {
                Divider().padding(.leading, 14)
                DatePicker("Leaving", selection: $tripStart, displayedComponents: .date).padding(14)
                Divider().padding(.leading, 14)
                DatePicker("Back", selection: $tripEnd, in: tripStart..., displayedComponents: .date).padding(14)
            }
            Divider().padding(.leading, 14)
            Picker("Currency", selection: $currency) {
                ForEach(["GBP", "EUR", "USD", "JPY", "CHF", "AUD", "CAD", "NZD", "SEK", "NOK", "DKK", "THB", "MXN"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            .padding(14)
        }
        .card(radius: 18)
    }

    private var coverPicker: some View {
        LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
            ForEach(CoverCategory.allCases) { category in
                Text(category.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.top, 10)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 58, maximum: 80), spacing: 12)], spacing: 14) {
                    ForEach(Cover.covers(in: category)) { c in
                        Button {
                            withAnimation(.spring) { cover = c }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            NotebookCover(cover: c)
                                .overlay(selectionRing(cover == c))
                                .overlay(alignment: .topTrailing) {
                                    if cover == c {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(.white, Theme.accent)
                                            .offset(x: 8, y: -8)
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(c.id.replacingOccurrences(of: "-", with: " "))
                    }
                }
            }
            Text("YOUR IMAGE")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.inkSecondary)
                .padding(.top, 10)
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    if let photo, cover == .photo {
                        NotebookCover(cover: .photo, photo: photo)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.inkTertiary, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                            .aspectRatio(0.72, contentMode: .fit)
                            .overlay {
                                VStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up").font(.title3)
                                    Text("Upload").font(.caption)
                                }
                                .foregroundStyle(Theme.inkSecondary)
                            }
                    }
                }
                .frame(width: 72)
                .overlay(selectionRing(cover == .photo))
            }
        }
    }

    private func selectionRing(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(on ? Theme.accent : .clear, lineWidth: 3)
            .padding(-5)
    }

    private func load() {
        guard let nb = notebook else {
            cover = Cover.randomIllustrated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { titleFocused = true }
            return
        }
        title = nb.title ?? ""
        kind = nb.notebookKind
        cover = nb.cover
        photo = nb.coverPhoto
        if let s = nb.tripStart { tripStart = s; hasDates = true } else { hasDates = false }
        if let e = nb.tripEnd { tripEnd = e }
        currency = nb.currencyCode
    }

    private func save() {
        let nb = notebook ?? Notebook.create(in: context, title: title, kind: kind, cover: cover)
        nb.title = title.trimmingCharacters(in: .whitespaces)
        nb.coverID = cover.id
        nb.coverPhoto = cover == .photo ? photo : nil
        nb.updatedAt = .now
        if kind == .trip {
            nb.tripStart = hasDates ? tripStart : nil
            nb.tripEnd = hasDates ? max(tripEnd, tripStart) : nil
            nb.currency = currency
        }
        persistence.save()
        if isNew { onCreate(nb) }
        dismiss()
    }
}

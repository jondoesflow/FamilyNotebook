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
    @State private var cover: CoverStyle = .midnight
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
                    NotebookCover(style: cover, photo: photo, title: title.isEmpty ? nil : title, showLabel: !title.isEmpty)
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
            Text("What is it?").font(.headline).foregroundStyle(Theme.ink)
            ForEach(NotebookKind.allCases) { k in
                Button {
                    withAnimation(.snappy) { kind = k }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: k.symbol)
                            .font(.headline)
                            .foregroundStyle(k.tint)
                            .frame(width: 40, height: 40)
                            .background(k.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k == .notes ? "Notebook" : "A \(k.name.lowercased())")
                                .font(Theme.serif(.headline, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(k.blurb).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: kind == k ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(kind == k ? k.tint : Theme.inkTertiary)
                    }
                    .padding(14)
                    .card(radius: 18)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(kind == k ? k.tint : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Cover").font(.headline).foregroundStyle(Theme.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 14)], spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        if let photo, cover == .photo {
                            NotebookCover(style: .photo, photo: photo)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.card)
                                .aspectRatio(0.72, contentMode: .fit)
                                .overlay(Image(systemName: "photo.badge.plus").font(.title3).foregroundStyle(Theme.inkSecondary))
                        }
                    }
                    .overlay(selectionRing(cover == .photo))
                }
                ForEach(CoverStyle.illustrated) { style in
                    Button {
                        withAnimation(.spring) { cover = style }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        NotebookCover(style: style).overlay(selectionRing(cover == style))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(style.name)
                }
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
            cover = CoverStyle.illustrated.randomElement() ?? .midnight
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
        nb.coverID = cover.rawValue
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

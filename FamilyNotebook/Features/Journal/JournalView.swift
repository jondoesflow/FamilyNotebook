import SwiftUI
import CoreData

struct JournalView: View {
    @ObservedObject var notebook: Notebook
    @EnvironmentObject private var persistence: Persistence
    @FetchRequest private var entries: FetchedResults<Note>
    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var openNote: Note?

    init(notebook: Notebook) {
        self.notebook = notebook
        _entries = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "entryDate", ascending: false),
                                                  NSSortDescriptor(key: "createdAt", ascending: false)],
                                predicate: NSPredicate(format: "notebook == %@ AND trashedAt == nil", notebook),
                                animation: .spring)
    }

    private var days: Set<Date> {
        let cal = Calendar.current
        return Set(entries.compactMap { $0.entryDate ?? $0.createdAt }.map { cal.startOfDay(for: $0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NotebookBanner(notebook: notebook, subtitle: "\(entries.count) entries")
                HStack(alignment: .top, spacing: 14) {
                    statsCard
                    CalendarCard(month: $month, days: days, tint: Theme.journal) { open(on: $0) }
                }
                promptCard
                if !entries.isEmpty {
                    SectionHeader(title: "Entries").padding(.top, 8)
                }
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        NavigationLink(value: Route.note(entry)) { JournalEntryCard(entry: entry) }
                            .buttonStyle(PressableStyle())
                            .contextMenu {
                                Button(entry.isStarred ? "Unstar" : "Star", systemImage: entry.isStarred ? "star.slash" : "star") {
                                    entry.isStarred.toggle(); persistence.save()
                                }
                                Button("Move to Trash", systemImage: "trash", role: .destructive) {
                                    entry.trashedAt = .now; persistence.save()
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
                FloatingNewButton(title: Journal.entry(on: .now, in: notebook) == nil ? "Write today" : "Today's entry",
                                  tint: Theme.journal) { open(on: .now) }
            }
        }
        .navigationDestination(item: $openNote) { NoteEditorView(note: $0) }
    }

    private var statsCard: some View {
        let streak = Journal.streak(for: notebook)
        let year = Calendar.current.component(.year, from: .now)
        let thisYear = days.filter { Calendar.current.component(.year, from: $0) == year }.count
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Streak", systemImage: "flame").font(.caption.weight(.semibold)).foregroundStyle(Color(hex: 0xE8772E))
                Text(streak == 1 ? "1 day" : "\(streak) days")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("In \(String(year))").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                Text("\(thisYear) days")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 130, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(radius: 18)
    }

    private var promptCard: some View {
        Button { open(on: .now) } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Theme.journal)
                Text(Journal.promptOfTheDay)
                    .font(Theme.serif(.body))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.inkTertiary)
            }
            .padding(16)
            .card(radius: 18)
        }
        .buttonStyle(PressableStyle())
        .disabled(!persistence.canEdit(notebook))
    }

    private func open(on date: Date) {
        if let existing = Journal.entry(on: date, in: notebook) {
            openNote = existing
        } else if persistence.canEdit(notebook), date <= .now {
            let note = Note.create(in: notebook, entryDate: Calendar.current.startOfDay(for: date))
            persistence.save()
            openNote = note
        }
    }
}

struct JournalEntryCard: View {
    @ObservedObject var entry: Note

    private var dateLabel: String {
        let d = entry.entryDate ?? entry.createdAt ?? .now
        let day = d.formatted(.dateTime.weekday(.wide).day()).uppercased()
        if Calendar.current.isDateInToday(d) { return "TODAY · \(day)" }
        if Calendar.current.isDateInYesterday(d) { return "YESTERDAY · \(day)" }
        return d.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateLabel)
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.journal)
                Spacer()
                if entry.isStarred { Image(systemName: "star.fill").font(.caption).foregroundStyle(Color(hex: 0xE8B02E)) }
                Avatar(name: entry.lastEditor, size: 18)
            }
            if !(entry.title ?? "").isEmpty {
                Text(entry.title ?? "")
                    .font(Theme.serif(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(entry.excerpt.isEmpty ? "Nothing yet — tap to write." : entry.excerpt)
                .font(Theme.serif(.subheadline))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18)
    }
}

struct CalendarCard: View {
    @Binding var month: Date
    var days: Set<Date>
    var tint: Color
    var onSelect: (Date) -> Void

    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(cal.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.inkSecondary)

            let cells = gridDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let has = days.contains(day)
                        let isToday = cal.isDateInToday(day)
                        Button { onSelect(day) } label: {
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 11, weight: has ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(isToday && has ? .white : has ? tint : day > .now ? Theme.inkTertiary : Theme.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background {
                                    Circle().fill(isToday && has ? tint : has ? tint.opacity(0.16) : .clear)
                                }
                                .overlay { if isToday && !has { Circle().strokeBorder(tint, lineWidth: 1) } }
                        }
                        .buttonStyle(.plain)
                        .disabled(day > .now)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .card(radius: 18)
    }

    private func shift(_ by: Int) {
        withAnimation(.snappy) { month = cal.date(byAdding: .month, value: by, to: month) ?? month }
    }

    private func gridDays() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: month)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var out: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            out.append(cal.date(byAdding: .day, value: d - 1, to: month))
        }
        return out
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

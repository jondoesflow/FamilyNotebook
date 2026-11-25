import SwiftUI
import CoreData

struct TripView: View {
    @ObservedObject var notebook: Notebook
    @EnvironmentObject private var persistence: Persistence
    @FetchRequest private var items: FetchedResults<TripItem>
    @FetchRequest private var expenses: FetchedResults<Expense>
    @FetchRequest private var notes: FetchedResults<Note>

    @State private var editingItem: TripItem?
    @State private var newItem = false
    @State private var editingExpense: Expense?
    @State private var newExpense = false
    @State private var openNote: Note?
    @State private var showAllExpenses = false

    init(notebook: Notebook) {
        self.notebook = notebook
        _items = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)],
                              predicate: NSPredicate(format: "notebook == %@", notebook), animation: .spring)
        _expenses = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
                                 predicate: NSPredicate(format: "notebook == %@", notebook), animation: .spring)
        _notes = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)],
                              predicate: NSPredicate(format: "notebook == %@ AND trashedAt == nil", notebook), animation: .spring)
    }

    private var canEdit: Bool { persistence.canEdit(notebook) }
    private var code: String { notebook.currencyCode }

    private var grouped: [(Date, [TripItem])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: items) { cal.startOfDay(for: $0.date ?? .now) }
        return dict.keys.sorted().map { ($0, dict[$0]!.sorted { ($0.date ?? .now) < ($1.date ?? .now) }) }
    }

    private var nextItem: TripItem? { items.first { ($0.date ?? .distantPast) > .now } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                itinerary
                spending
                notesSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .bottom) {
            if canEdit {
                Menu {
                    Button("Add a plan", systemImage: "calendar.badge.plus") { newItem = true }
                    Button("Add an expense", systemImage: "creditcard") { newExpense = true }
                    Button("New note", systemImage: "square.and.pencil") {
                        openNote = Note.create(in: notebook); persistence.save()
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 15)
                        .background(Theme.trip, in: Capsule())
                        .shadow(color: Theme.trip.opacity(0.35), radius: 14, y: 8)
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $newItem) { TripItemForm(notebook: notebook, item: nil) }
        .sheet(item: $editingItem) { TripItemForm(notebook: notebook, item: $0) }
        .sheet(isPresented: $newExpense) { ExpenseForm(notebook: notebook, expense: nil) }
        .sheet(item: $editingExpense) { ExpenseForm(notebook: notebook, expense: $0) }
        .navigationDestination(item: $openNote) { NoteEditorView(note: $0) }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(style: notebook.cover, photo: notebook.coverPhoto)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                if let countdown = Trip.countdown(for: notebook) {
                    Text(countdown)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(notebook.displayTitle)
                        .font(Theme.display(32))
                        .foregroundStyle(.white)
                    if let s = notebook.tripStart {
                        Text(dateRange(s, notebook.tripEnd))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .padding(.top, 8)
    }

    private func dateRange(_ s: Date, _ e: Date?) -> String {
        guard let e, !Calendar.current.isDate(s, inSameDayAs: e) else { return s.formatted(.dateTime.day().month(.wide)) }
        return (s..<max(e, s.addingTimeInterval(1))).formatted(.interval.day().month(.abbreviated))
    }

    // MARK: Itinerary

    @ViewBuilder private var itinerary: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Itinerary", trailing: items.isEmpty ? nil : "\(items.count) plans")
            if items.isEmpty {
                emptyCard(symbol: "map", text: "Flights, trains, places to stay and things to do — each on its day, at its time.",
                          button: "Add the first plan") { newItem = true }
            }
            ForEach(grouped, id: \.0) { day, dayItems in
                VStack(alignment: .leading, spacing: 10) {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.top, 4)
                    ForEach(dayItems) { item in
                        Button { if canEdit { editingItem = item } } label: {
                            TripItemRow(item: item, code: code, isNext: item == nextItem, isLast: item == dayItems.last)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if canEdit {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    persistence.viewContext.delete(item); persistence.save()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Spending

    private var spending: some View {
        let balance = Trip.balance(for: notebook)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Spending")
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Total", systemImage: "creditcard").font(.subheadline.weight(.medium)).foregroundStyle(Theme.inkSecondary)
                    Text(Trip.money(balance.total, code))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Spacer()
                    Text(People.all.map { "\($0) \(Trip.money(balance.paid[$0, default: 0], code))" }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(16)
                Divider().padding(.horizontal, 16)
                HStack(spacing: 10) {
                    if let s = balance.settlement {
                        Avatar(name: s.from, size: 26)
                        Text("\(s.from) owes \(s.to)").font(.subheadline).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(Trip.money(s.amount, code)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        if canEdit {
                            Button("Settle") { settle(s.from, s.to, s.amount) }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.trip)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(Theme.trip, lineWidth: 1.2))
                        }
                    } else {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                        Text(balance.total > 0 ? "All square" : "No spending yet").font(.subheadline).foregroundStyle(Theme.ink)
                        Spacer()
                    }
                }
                .padding(16)
            }
            .card(radius: 18)

            let visible = showAllExpenses ? Array(expenses) : Array(expenses.prefix(4))
            ForEach(visible) { e in
                Button { if canEdit { editingExpense = e } } label: { ExpenseRow(expense: e, code: code) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if canEdit {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                persistence.viewContext.delete(e); persistence.save()
                            }
                        }
                    }
            }
            if expenses.count > 4 {
                Button(showAllExpenses ? "Show less" : "Show all \(expenses.count)") { withAnimation { showAllExpenses.toggle() } }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.trip)
            }
        }
    }

    private func settle(_ from: String, _ to: String, _ amount: Double) {
        let e = Expense(context: persistence.viewContext)
        persistence.assign(e, alongside: notebook)
        e.uuid = UUID()
        e.title = "\(from) paid \(to) back"
        e.amount = (amount * 100).rounded() / 100
        e.paidBy = from
        e.splitWith = to
        e.isSettlement = true
        e.date = .now
        e.notebook = notebook
        notebook.updatedAt = .now
        persistence.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Notes

    @ViewBuilder private var notesSection: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Notes")
                ForEach(notes) { note in
                    NavigationLink(value: Route.note(note)) { NoteRow(note: note) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func emptyCard(symbol: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.trip)
            Text(text).font(Theme.serif(.body)).foregroundStyle(Theme.inkSecondary)
            if canEdit {
                Button(button, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.trip)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18)
    }
}

struct TripItemRow: View {
    @ObservedObject var item: TripItem
    var code: String
    var isNext: Bool
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.date?.formatted(.dateTime.hour().minute()) ?? "")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 16)
            VStack(spacing: 0) {
                Image(systemName: item.itemKind.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(item.itemKind.color, in: Circle())
                    .padding(.top, 10)
                if !isLast {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.itemKind.name.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(item.itemKind.color)
                    if isNext { Chip(text: "Up next", tint: Theme.trip) }
                }
                Text(item.title ?? "")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                }
                if let memo = item.memo, !memo.isEmpty {
                    Text(memo).font(Theme.serif(.footnote)).foregroundStyle(Theme.inkSecondary).padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: 16)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isNext ? Theme.trip.opacity(0.6) : .clear, lineWidth: 1.5))
            .padding(.bottom, 6)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension TripItemRow {
    var detail: String {
        var parts: [String] = []
        if let d = item.detail, !d.isEmpty { parts.append(d) }
        if item.cost > 0 {
            let money = Trip.money(item.cost, code)
            if let payer = item.paidBy, !payer.isEmpty {
                parts.append(payer + " pays " + money)
            } else {
                parts.append(money)
            }
        }
        return parts.joined(separator: " · ")
    }
}

struct ExpenseRow: View {
    @ObservedObject var expense: Expense
    var code: String

    var body: some View {
        HStack(spacing: 12) {
            Avatar(name: expense.paidBy, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title ?? "Expense").font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                Text(caption).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text(Trip.money(expense.amount, code))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(expense.isSettlement ? Theme.accent : Theme.ink)
        }
        .padding(14)
        .card(radius: 16)
    }

    private var caption: String {
        let date = expense.date?.formatted(.dateTime.day().month(.abbreviated)) ?? ""
        if expense.isSettlement { return "Settled up · \(date)" }
        let split = (expense.splitWith ?? "").split(separator: ",").map(String.init)
        let who = split.isEmpty || Set(split) == Set(People.all) ? "Split between you" : "Just for \(split.joined(separator: " & "))"
        return "\(expense.paidBy ?? "") paid · \(who) · \(date)"
    }
}

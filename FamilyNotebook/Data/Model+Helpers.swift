import CoreData
import SwiftUI

enum NotebookKind: Int16, CaseIterable, Identifiable {
    case notes = 0, journal = 1, trip = 2
    var id: Int16 { rawValue }

    var name: String {
        switch self {
        case .notes: "Notebook"
        case .journal: "Journal"
        case .trip: "Trip"
        }
    }

    var blurb: String {
        switch self {
        case .notes: "Ideas, recipes, lists — anything."
        case .journal: "One entry a day, with a streak and a calendar."
        case .trip: "Itinerary by day, plus who owes whom."
        }
    }

    var symbol: String {
        switch self {
        case .notes: "doc.text"
        case .journal: "sparkles"
        case .trip: "airplane"
        }
    }

    var tint: Color {
        switch self {
        case .notes: Theme.accent
        case .journal: Theme.journal
        case .trip: Theme.trip
        }
    }
}

extension Notebook {
    var notebookKind: NotebookKind {
        get { NotebookKind(rawValue: kind) ?? .notes }
        set { kind = newValue.rawValue }
    }

    var displayTitle: String {
        let t = (title ?? "").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Untitled" : t
    }

    var cover: Cover { Cover.find(coverID) }

    var isLocked: Bool { pinHash != nil }

    var liveNotes: [Note] {
        ((notes as? Set<Note>) ?? []).filter { $0.trashedAt == nil }
    }

    var sortedTripItems: [TripItem] {
        ((tripItems as? Set<TripItem>) ?? []).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    var sortedExpenses: [Expense] {
        ((expenses as? Set<Expense>) ?? []).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    var currencyCode: String { currency ?? Locale.current.currency?.identifier ?? "GBP" }

    var subtitle: String {
        switch notebookKind {
        case .notes:
            let n = liveNotes.count
            return n == 1 ? "1 note" : "\(n) notes"
        case .journal:
            let streak = Journal.streak(for: self)
            return streak > 0 ? "\(streak)-day streak" : "\(liveNotes.count) entries"
        case .trip:
            return Trip.countdown(for: self) ?? "Trip"
        }
    }

    var lastActivity: Date {
        let noteDates = liveNotes.compactMap(\.updatedAt)
        return ([updatedAt ?? createdAt ?? .distantPast] + noteDates).max() ?? .distantPast
    }

    @discardableResult
    static func create(in context: NSManagedObjectContext, title: String, kind: NotebookKind, cover: Cover) -> Notebook {
        let nb = Notebook(context: context)
        nb.uuid = UUID()
        nb.title = title
        nb.notebookKind = kind
        nb.coverID = cover.rawValue
        nb.createdAt = .now
        nb.updatedAt = .now
        nb.sortIndex = -Date.now.timeIntervalSince1970
        return nb
    }
}

extension Note {
    var displayTitle: String {
        let t = (title ?? "").trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { return t }
        if let entryDate, notebook?.notebookKind == .journal {
            return entryDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        return "Untitled"
    }

    var excerpt: String {
        let text = (plainText ?? "").replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return String(text.prefix(160))
    }

    var readingMinutes: Int {
        let words = (plainText ?? "").split(whereSeparator: \.isWhitespace).count
        return max(1, Int((Double(words) / 220).rounded(.up)))
    }

    var sortedAttachments: [Attachment] {
        ((attachments as? Set<Attachment>) ?? []).sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    var hasDrawing: Bool { (drawing?.count ?? 0) > 0 }

    @discardableResult
    static func create(in notebook: Notebook, title: String = "", entryDate: Date? = nil) -> Note {
        let context = notebook.managedObjectContext ?? Persistence.shared.viewContext
        let note = Note(context: context)
        Persistence.shared.assign(note, alongside: notebook)
        note.uuid = UUID()
        note.title = title
        note.createdAt = .now
        note.updatedAt = .now
        note.entryDate = entryDate
        note.lastEditor = People.me
        note.notebook = notebook
        notebook.updatedAt = .now
        return note
    }

    func touch() {
        updatedAt = .now
        lastEditor = People.me
        notebook?.updatedAt = .now
    }

    var markdown: String {
        var out = "# \(displayTitle)\n\n"
        if let body, let runs = try? JSONDecoder().decode([RichRun].self, from: body) {
            out += RichTextCodec.markdown(from: runs)
        } else {
            out += plainText ?? ""
        }
        return out
    }
}

// MARK: - People

/// The two of you. Names are editable in Settings; each phone remembers who is holding it.
enum People {
    static let defaultsA = "Jon"
    static let defaultsB = "Katie"

    static var personA: String { UserDefaults.standard.string(forKey: "personA") ?? defaultsA }
    static var personB: String { UserDefaults.standard.string(forKey: "personB") ?? defaultsB }
    static var all: [String] { [personA, personB] }
    static var me: String { UserDefaults.standard.string(forKey: "me") ?? personA }
    static var partner: String { me == personA ? personB : personA }

    static func color(for name: String?) -> Color {
        guard let name else { return Theme.inkSecondary }
        if name == personA { return Color(hex: 0x2D6FD1) }
        if name == personB { return Color(hex: 0xD9541E) }
        return Theme.inkSecondary
    }
}

// MARK: - Journal maths

enum Journal {
    static func entryDays(for notebook: Notebook) -> Set<Date> {
        let cal = Calendar.current
        return Set(notebook.liveNotes.compactMap { $0.entryDate ?? $0.createdAt }.map { cal.startOfDay(for: $0) })
    }

    static func streak(for notebook: Notebook) -> Int {
        let days = entryDays(for: notebook)
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    static func entry(on date: Date, in notebook: Notebook) -> Note? {
        let cal = Calendar.current
        return notebook.liveNotes.first { cal.isDate($0.entryDate ?? $0.createdAt ?? .distantPast, inSameDayAs: date) }
    }

    static let prompts = [
        "What made you smile this week?",
        "What's something small you're grateful for today?",
        "Where did you feel most at home today?",
        "What do you want to remember about this season?",
        "What did you learn about each other lately?",
        "Describe a meal worth remembering.",
        "What's one thing you'd like to do together this month?",
        "What surprised you today?",
        "Write about a sound, a smell or a colour from today.",
        "What are you looking forward to?",
        "What would make tomorrow a good day?",
        "Which moment today would you replay?",
        "Who made your day easier, and how?",
        "What's been on your mind on the walk home?",
    ]

    static var promptOfTheDay: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return prompts[day % prompts.count]
    }
}

// MARK: - Trip maths

enum TripItemKind: Int16, CaseIterable, Identifiable {
    case flight, train, car, stay, food, activity, other
    var id: Int16 { rawValue }

    var name: String {
        switch self {
        case .flight: "Flight"
        case .train: "Train"
        case .car: "Drive"
        case .stay: "Stay"
        case .food: "Food"
        case .activity: "Plan"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .flight: "airplane"
        case .train: "tram.fill"
        case .car: "car.fill"
        case .stay: "bed.double.fill"
        case .food: "fork.knife"
        case .activity: "star.fill"
        case .other: "mappin"
        }
    }

    var color: Color {
        switch self {
        case .flight: Color(hex: 0x2F80ED)
        case .train: Color(hex: 0x0E9F8F)
        case .car: Color(hex: 0x8E6CC9)
        case .stay: Color(hex: 0x7B61FF)
        case .food: Color(hex: 0xE0484D)
        case .activity: Color(hex: 0xE59A1C)
        case .other: Color(hex: 0x6E6A64)
        }
    }
}

extension TripItem {
    var itemKind: TripItemKind {
        get { TripItemKind(rawValue: kind) ?? .other }
        set { kind = newValue.rawValue }
    }
}

struct Balance {
    var total: Double = 0
    var paid: [String: Double] = [:]   // spending paid by each person (excluding settlements)
    var net: [String: Double] = [:]    // + means they're owed money

    /// (debtor, creditor, amount) or nil when you're square.
    var settlement: (from: String, to: String, amount: Double)? {
        let people = People.all
        guard let a = people.first, let b = people.last, a != b else { return nil }
        let na = net[a, default: 0]
        if abs(na) < 0.005 { return nil }
        return na > 0 ? (b, a, na) : (a, b, -na)
    }
}

enum Trip {
    static func countdown(for notebook: Notebook) -> String? {
        guard let start = notebook.tripStart else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: notebook.tripEnd ?? start)
        if today < s {
            let days = cal.dateComponents([.day], from: today, to: s).day ?? 0
            return days == 1 ? "Tomorrow" : "In \(days) days"
        }
        if today <= e { return "Happening now" }
        return "Been there"
    }

    static func balance(for notebook: Notebook) -> Balance {
        var b = Balance()
        let people = People.all
        func apply(amount: Double, paidBy: String?, split: [String], counts: Bool) {
            guard amount > 0, let payer = paidBy, !payer.isEmpty else { return }
            let sharers = split.isEmpty ? people : split
            if counts {
                b.total += amount
                b.paid[payer, default: 0] += amount
            }
            b.net[payer, default: 0] += amount
            for p in sharers { b.net[p, default: 0] -= amount / Double(sharers.count) }
        }
        for item in notebook.sortedTripItems where item.cost > 0 {
            apply(amount: item.cost, paidBy: item.paidBy, split: [], counts: true)
        }
        for e in notebook.sortedExpenses {
            let split = (e.splitWith ?? "").split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
            apply(amount: e.amount, paidBy: e.paidBy, split: split, counts: !e.isSettlement)
        }
        return b
    }

    static func money(_ value: Double, _ code: String) -> String {
        value.formatted(.currency(code: code).precision(.fractionLength(value.rounded() == value ? 0 : 2)))
    }
}

// MARK: - Versions & moving

extension Note {
    var sortedVersions: [NoteVersion] {
        ((versions as? Set<NoteVersion>) ?? []).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// Saves how the note looks right now as a version, unless nothing changed since the last one.
    func snapshot(maxVersions: Int = 50) {
        guard let context = managedObjectContext else { return }
        let latest = sortedVersions.first
        if latest?.body == body && latest?.title == title { return }
        if (plainText ?? "").isEmpty && (title ?? "").isEmpty && latest == nil { return }
        let v = NoteVersion(context: context)
        Persistence.shared.assign(v, alongside: self)
        v.uuid = UUID()
        v.title = title
        v.body = body
        v.plainText = plainText
        v.author = People.me
        v.createdAt = .now
        v.note = self
        for old in sortedVersions.dropFirst(maxVersions) { context.delete(old) }
    }

    func restore(_ version: NoteVersion) {
        snapshot()
        title = version.title
        body = version.body
        plainText = version.plainText
        touch()
        snapshot()
    }

    /// Moves the note to another notebook. Notes can't hop between iCloud stores (your own
    /// notebooks vs. ones shared with you), so in that case we copy it across and delete the original.
    @discardableResult
    func move(to target: Notebook) -> Note {
        guard let context = managedObjectContext else { return self }
        if target.objectID.persistentStore == objectID.persistentStore {
            notebook?.updatedAt = .now
            notebook = target
            target.updatedAt = .now
            entryDate = target.notebookKind == .journal ? (entryDate ?? Calendar.current.startOfDay(for: createdAt ?? .now)) : nil
            return self
        }
        let copy = Note.create(in: target, title: title ?? "")
        copy.body = body
        copy.plainText = plainText
        copy.drawing = drawing
        copy.isPinned = isPinned
        copy.pinHash = nil
        copy.createdAt = createdAt
        copy.entryDate = target.notebookKind == .journal ? (entryDate ?? Calendar.current.startOfDay(for: createdAt ?? .now)) : nil
        for att in sortedAttachments {
            let a = Attachment(context: context)
            Persistence.shared.assign(a, alongside: target)
            a.uuid = UUID()
            a.createdAt = att.createdAt
            a.imageData = att.imageData
            a.note = copy
        }
        context.delete(self)
        return copy
    }
}

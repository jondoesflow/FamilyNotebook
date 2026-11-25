import SwiftUI

struct TripItemForm: View {
    var notebook: Notebook
    var item: TripItem?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var persistence: Persistence

    @State private var kind: TripItemKind = .activity
    @State private var title = ""
    @State private var detail = ""
    @State private var memo = ""
    @State private var date = Date.now
    @State private var cost = ""
    @State private var paidBy = People.me

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(TripItemKind.allCases) { k in
                                Button { withAnimation(.snappy) { kind = k } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: k.symbol)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(kind == k ? .white : k.color)
                                            .frame(width: 44, height: 44)
                                            .background(kind == k ? k.color : k.color.opacity(0.14), in: Circle())
                                        Text(k.name).font(.caption2).foregroundStyle(Theme.ink)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollIndicators(.hidden)
                }
                Section {
                    TextField(placeholder, text: $title)
                    TextField(detailPlaceholder, text: $detail)
                    DatePicker("When", selection: $date)
                }
                Section("Cost (optional)") {
                    TextField("0", text: $cost).keyboardType(.decimalPad)
                    Picker("Paid by", selection: $paidBy) {
                        ForEach(People.all, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Notes") {
                    TextField("Booking reference, address, anything", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }
                if item != nil {
                    Section {
                        Button("Delete plan", role: .destructive) {
                            if let item { persistence.viewContext.delete(item); persistence.save() }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle(item == nil ? "New plan" : "Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var placeholder: String {
        switch kind {
        case .flight: "London → Lisbon"
        case .train: "Lisbon → Porto"
        case .car: "Pick up the hire car"
        case .stay: "Casa de Alfama"
        case .food: "Taberna da Esquina"
        case .activity: "Sunset at Santa Luzia"
        case .other: "Title"
        }
    }

    private var detailPlaceholder: String {
        switch kind {
        case .flight: "TP 1027 · Terminal 2"
        case .stay: "3 nights"
        case .train: "Coach 4, seats 31–32"
        default: "Details"
        }
    }

    private func load() {
        if let s = notebook.tripStart, item == nil {
            date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: s) ?? s
        }
        guard let item else { return }
        kind = item.itemKind
        title = item.title ?? ""
        detail = item.detail ?? ""
        memo = item.memo ?? ""
        date = item.date ?? .now
        cost = item.cost > 0 ? String(item.cost) : ""
        paidBy = item.paidBy ?? People.me
    }

    private func save() {
        let ctx = persistence.viewContext
        let it = item ?? {
            let new = TripItem(context: ctx)
            persistence.assign(new, alongside: notebook)
            new.uuid = UUID()
            new.notebook = notebook
            return new
        }()
        it.itemKind = kind
        it.title = title
        it.detail = detail
        it.memo = memo
        it.date = date
        it.cost = Double(cost.replacingOccurrences(of: ",", with: ".")) ?? 0
        it.paidBy = it.cost > 0 ? paidBy : nil
        notebook.updatedAt = .now
        persistence.save()
        dismiss()
    }
}

struct ExpenseForm: View {
    var notebook: Notebook
    var expense: Expense?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var persistence: Persistence

    @State private var title = ""
    @State private var amount = ""
    @State private var paidBy = People.me
    @State private var split: Set<String> = Set(People.all)
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What for?", text: $title)
                    HStack {
                        Text(Locale.current.localizedString(forCurrencyCode: notebook.currencyCode) ?? notebook.currencyCode)
                            .foregroundStyle(Theme.inkSecondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Paid by") {
                    Picker("Paid by", selection: $paidBy) {
                        ForEach(People.all, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ForEach(People.all, id: \.self) { person in
                        Button {
                            if split.contains(person) { if split.count > 1 { split.remove(person) } } else { split.insert(person) }
                        } label: {
                            HStack {
                                Avatar(name: person, size: 26)
                                Text(person).foregroundStyle(Theme.ink)
                                Spacer()
                                if split.contains(person) { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                    }
                } header: {
                    Text("For")
                } footer: {
                    Text("Untick someone for things that were just for the other person.")
                }
                if expense != nil {
                    Section {
                        Button("Delete expense", role: .destructive) {
                            if let expense { persistence.viewContext.delete(expense); persistence.save() }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle(expense == nil ? "New expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold).disabled(parsedAmount <= 0)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var parsedAmount: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private func load() {
        guard let e = expense else { return }
        title = e.title ?? ""
        amount = String(e.amount)
        paidBy = e.paidBy ?? People.me
        let s = (e.splitWith ?? "").split(separator: ",").map(String.init)
        split = s.isEmpty ? Set(People.all) : Set(s)
        date = e.date ?? .now
    }

    private func save() {
        let ctx = persistence.viewContext
        let e = expense ?? {
            let new = Expense(context: ctx)
            persistence.assign(new, alongside: notebook)
            new.uuid = UUID()
            new.notebook = notebook
            return new
        }()
        e.title = title.isEmpty ? "Expense" : title
        e.amount = parsedAmount
        e.paidBy = paidBy
        e.splitWith = split == Set(People.all) ? "" : People.all.filter(split.contains).joined(separator: ",")
        e.date = date
        notebook.updatedAt = .now
        persistence.save()
        dismiss()
    }
}

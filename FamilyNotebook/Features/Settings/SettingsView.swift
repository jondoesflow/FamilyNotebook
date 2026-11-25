import SwiftUI
import CloudKit
import CoreData

struct SettingsView: View {
    @EnvironmentObject private var persistence: Persistence
    @AppStorage("me") private var me: String = ""
    @AppStorage("personA") private var personA: String = People.defaultsA
    @AppStorage("personB") private var personB: String = People.defaultsB
    @AppStorage("appearance") private var appearance: Int = 0
    @State private var accountStatus: String = "Checking…"

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Avatar(name: me, size: 48)
                    VStack(alignment: .leading) {
                        Text(me).font(Theme.serif(.title3, weight: .semibold))
                        Text("This phone").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
                Picker("I am", selection: $me) {
                    Text(personA).tag(personA)
                    Text(personB).tag(personB)
                }
            }

            Section {
                TextField("First person", text: $personA)
                    .onChange(of: personA) { old, new in if me == old { me = new } }
                TextField("Second person", text: $personB)
                    .onChange(of: personB) { old, new in if me == old { me = new } }
            } header: {
                Text("The two of you")
            } footer: {
                Text("Use the same names on both phones so trip expenses add up.")
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section {
                NavigationLink { TrashView() } label: { Label("Trash", systemImage: "trash") }
            } footer: {
                Text("Deleted notes stay in the Trash for 30 days.")
            }

            Section {
                LabeledContent("iCloud", value: accountStatus)
                LabeledContent("Environment", value: persistence.cloudKitEnvironment)
                if let err = persistence.lastSyncError {
                    Text(err).font(.footnote).foregroundStyle(Theme.warning)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Everything is stored in your own iCloud. Shared notebooks live in a space only the two of you can see.")
            }

            Section {
                LabeledContent("Version", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
            } footer: {
                Text("Made for \(personA) & \(personB).")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .font(Theme.serif(.footnote))
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("Settings")
        .task { await loadAccount() }
    }

    private func loadAccount() async {
        do {
            let status = try await persistence.ckContainer.accountStatus()
            accountStatus = switch status {
            case .available: "Signed in"
            case .noAccount: "Not signed in"
            case .restricted: "Restricted"
            case .temporarilyUnavailable: "Temporarily unavailable"
            default: "Unknown"
            }
        } catch {
            accountStatus = "Unavailable"
        }
    }
}

struct TrashView: View {
    @EnvironmentObject private var persistence: Persistence
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "trashedAt", ascending: false)],
                  predicate: NSPredicate(format: "trashedAt != nil"), animation: .spring)
    private var notes: FetchedResults<Note>

    var body: some View {
        List {
            if notes.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash", description: Text("Deleted notes appear here for 30 days."))
                    .listRowBackground(Color.clear)
            }
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.displayTitle).font(Theme.serif(.headline))
                    Text("\(note.notebook?.displayTitle ?? "") · deleted \(note.trashedAt?.relativeShort ?? "")")
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                .swipeActions(edge: .leading) {
                    Button("Restore") { note.trashedAt = nil; persistence.save() }.tint(Theme.accent)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { persistence.viewContext.delete(note); persistence.save() }
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("Trash")
    }
}

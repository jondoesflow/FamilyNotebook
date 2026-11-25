import CoreData
import CloudKit
import Combine
import UIKit

/// Core Data + iCloud. Two stores:
///  - private: everything you create
///  - shared: notebooks someone has shared with you
/// Sharing a notebook moves it (and its notes, plans and expenses) into its own iCloud zone
/// that both of you can read and write.
final class Persistence: ObservableObject {
    static let shared = Persistence()

    let container: NSPersistentCloudKitContainer
    let containerIdentifier: String
    let cloudKitEnvironment: String
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?

    /// Bumped whenever sharing state may have changed, so views can refresh badges.
    @Published var shareRevision = 0
    @Published var lastSyncError: String?

    private var shareCache: [NSManagedObjectID: CKShare] = [:]
    private var cancellables = Set<AnyCancellable>()

    var ckContainer: CKContainer { CKContainer(identifier: containerIdentifier) }
    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        let info = Bundle.main.infoDictionary ?? [:]
        containerIdentifier = (info["CloudKitContainerID"] as? String) ?? "iCloud.com.jondoesflow.FamilyNotebook"
        cloudKitEnvironment = (info["CloudKitEnvironment"] as? String) ?? "Production"

        container = NSPersistentCloudKitContainer(name: "Model")

        let base = NSPersistentContainer.defaultDirectoryURL()
        let privateDescription = NSPersistentStoreDescription(url: base.appendingPathComponent("notebook-private.sqlite"))
        let sharedDescription = NSPersistentStoreDescription(url: base.appendingPathComponent("notebook-shared.sqlite"))

        for (description, scope) in [(privateDescription, CKDatabase.Scope.private), (sharedDescription, .shared)] {
            if inMemory { description.url = URL(fileURLWithPath: "/dev/null") }
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if !inMemory {
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
                options.databaseScope = scope
                description.cloudKitContainerOptions = options
            }
        }
        container.persistentStoreDescriptions = inMemory ? [privateDescription] : [privateDescription, sharedDescription]

        container.loadPersistentStores { [weak self] description, error in
            if let error {
                print("Store failed to load: \(error)")
                return
            }
            guard let self, let url = description.url else { return }
            let store = self.container.persistentStoreCoordinator.persistentStore(for: url)
            if description.cloudKitContainerOptions?.databaseScope == .shared {
                self.sharedStore = store
            } else {
                self.privateStore = store
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "app"
        try? container.viewContext.setQueryGenerationFrom(.current)

        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.shareCache.removeAll()
                self?.shareRevision += 1
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event, event.endDate != nil else { return }
                self?.lastSyncError = event.error?.localizedDescription
            }
            .store(in: &cancellables)
    }

    // MARK: - Saving

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do { try context.save() } catch { print("Save failed: \(error)") }
    }

    /// New objects that belong to a notebook must live in the same store as the notebook,
    /// otherwise notes added to a shared notebook would never reach the other person.
    func assign(_ object: NSManagedObject, alongside parent: NSManagedObject) {
        guard let store = parent.objectID.persistentStore else { return }
        container.viewContext.assign(object, to: store)
    }

    // MARK: - Sharing

    func isShared(_ object: NSManagedObject) -> Bool {
        if object.objectID.persistentStore == sharedStore, sharedStore != nil { return true }
        return share(for: object) != nil
    }

    /// True when the notebook was shared *with* me (I'm not the owner).
    func isParticipantCopy(_ object: NSManagedObject) -> Bool {
        sharedStore != nil && object.objectID.persistentStore == sharedStore
    }

    func share(for object: NSManagedObject) -> CKShare? {
        guard !object.objectID.isTemporaryID else { return nil }
        if let cached = shareCache[object.objectID] { return cached }
        let shares = try? container.fetchShares(matching: [object.objectID])
        let share = shares?[object.objectID]
        if let share { shareCache[object.objectID] = share }
        return share
    }

    func canEdit(_ object: NSManagedObject) -> Bool {
        container.canUpdateRecord(forManagedObjectWith: object.objectID)
    }

    @MainActor
    func makeShare(for notebook: Notebook) async throws -> CKShare {
        save()
        if let existing = share(for: notebook) { return existing }
        let (_, share, _) = try await container.share([notebook], to: nil)
        share[CKShare.SystemFieldKey.title] = notebook.displayTitle as CKRecordValue
        share.publicPermission = .none
        shareCache[notebook.objectID] = share
        shareRevision += 1
        return share
    }

    func persistUpdatedShare(_ share: CKShare) {
        guard let store = privateStore else { return }
        container.persistUpdatedShare(share, in: store) { _, error in
            if let error { print("Persist share failed: \(error)") }
        }
        DispatchQueue.main.async { self.shareCache.removeAll(); self.shareRevision += 1 }
    }

    func acceptShare(_ metadata: CKShare.Metadata) {
        guard let store = sharedStore else { return }
        container.acceptShareInvitations(from: [metadata], into: store) { _, error in
            if let error { print("Accept share failed: \(error)") }
            DispatchQueue.main.async { self.shareCache.removeAll(); self.shareRevision += 1 }
        }
    }

    func purgeShare(_ share: CKShare) {
        guard let store = sharedStore else { return }
        container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { _, error in
            if let error { print("Purge failed: \(error)") }
        }
    }

    // MARK: - Housekeeping

    /// Notes in the trash for more than 30 days are deleted for good.
    func emptyOldTrash() {
        let request = Note.fetchRequest()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        request.predicate = NSPredicate(format: "trashedAt != nil AND trashedAt < %@", cutoff as NSDate)
        let context = container.viewContext
        (try? context.fetch(request))?.forEach(context.delete)
        save()
    }

    /// In the Development environment, push the full data model to iCloud so it can be
    /// deployed to Production from the CloudKit Console. Runs once per install.
    func initializeSchemaIfNeeded() {
        guard cloudKitEnvironment == "Development" else { return }
        let key = "didInitializeCloudKitSchema-v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        DispatchQueue.global(qos: .utility).async {
            do {
                try self.container.initializeCloudKitSchema(options: [])
                UserDefaults.standard.set(true, forKey: key)
                print("CloudKit schema initialised")
            } catch {
                print("Schema init failed: \(error)")
                DispatchQueue.main.async { self.lastSyncError = "Schema: \(error.localizedDescription)" }
            }
        }
    }
}

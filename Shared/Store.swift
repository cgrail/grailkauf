import CloudKit
import CoreData
import GrailkaufCore
import Observation

/// The data of the household: one list. iCloud stores the list and shares it with invited people.
@MainActor @Observable
final class Store {
    static let containerID = "iCloud.de.grails.grailkauf"

    private(set) var state = ListState()
    /// The full history of the active list.
    private(set) var entries: [Entry] = []
    /// The learned order of item names.
    private(set) var order: [String] = []
    /// Last successful import from iCloud on this device.
    private(set) var lastSync = UserDefaults.standard.object(forKey: "lastSync") as? Date
    var problem: String?
    /// The names of items that the last `add` had on the list already. The older copies are gone.
    var repeated: String?

    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored let container: NSPersistentCloudKitContainer
    @ObservationIgnored private let ownsList: Bool
    @ObservationIgnored private var refreshQueued = false

    private var context: NSManagedObjectContext { container.viewContext }

    var privateStore: NSPersistentStore? { store(named: "private.sqlite") }
    var sharedStore: NSPersistentStore? { store(named: "shared.sqlite") }

    private func store(named name: String) -> NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first { $0.url?.lastPathComponent == name }
    }

    /// - Parameter ownsList: the phone creates the list of the household. The Watch only reads and ticks.
    init(ownsList: Bool) {
        self.ownsList = ownsList
        container = NSPersistentCloudKitContainer(name: "Grailkauf", managedObjectModel: makeModel())
        let folder = NSPersistentContainer.defaultDirectoryURL()
        container.persistentStoreDescriptions = [CKDatabase.Scope.private, .shared].map { scope in
            let file = scope == .private ? "private.sqlite" : "shared.sqlite"
            let description = NSPersistentStoreDescription(url: folder.appending(path: file))
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.containerID)
            options.databaseScope = scope
            description.cloudKitContainerOptions = options
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            return description
        }
        var failure: String?
        container.loadPersistentStores { _, error in failure = failure ?? error?.localizedDescription }
        problem = failure
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        let center = NotificationCenter.default
        center.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.queueRefresh() }
        }
        // Not on the main queue: CloudKit waits for the observer, and calls such as `share` make the main thread
        // wait for CloudKit. An observer on the main queue then freezes the app.
        center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: container, queue: nil
        ) { [weak self] note in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = note.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                  event.type == .import, event.succeeded, let finished = event.endDate
            else { return }
            Task { @MainActor in self?.synced(at: finished) }
        }
    }

    private func synced(at date: Date) {
        lastSync = date
        UserDefaults.standard.set(date, forKey: "lastSync")
        queueRefresh()
    }

    private func queueRefresh() {
        guard !refreshQueued else { return }
        refreshQueued = true
        Task {
            refreshQueued = false
            refresh()
        }
    }

    /// Builds all that the screens show. Call it also when the app becomes active.
    /// Time alone can change the list: a trip ends four hours after its last tick.
    // shortcut: reads the full history on every change, cache the order when a household has tens of
    // thousands of purchases.
    func refresh() {
        let now = Date.now
        let list = activeList()
        let entries = (list?.items ?? []).compactMap(\.entry)
        let moves = (list?.moves ?? []).compactMap(\.move)
        let order = ListState.order(entries: entries, moves: moves, now: now)
        var state = ListState(entries: entries, order: order, lastSync: lastSync, now: now)
        state.sections = list?.sections?.split(separator: ",").map(String.init)
        if entries != self.entries { self.entries = entries }
        if order != self.order { self.order = order }
        if state != self.state { self.state = state }
        onChange()
    }

    /// The list that this device uses. A list that someone shared with us wins over our own list.
    func activeList() -> ShoppingList? {
        let lists = ((try? context.fetch(NSFetchRequest<ShoppingList>(entityName: "ShoppingList"))) ?? [])
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        if let joined = lists.first(where: { $0.objectID.persistentStore === sharedStore }) { return joined }
        guard ownsList else { return lists.first }
        guard let oldest = lists.first else {
            guard let privateStore else { return nil }
            let list = ShoppingList(context: context)
            context.assign(list, to: privateStore)
            list.id = UUID()
            list.createdAt = .now
            save()
            return list
        }
        // A device can start a list before its first sync brings the existing list. Merge it into the oldest.
        for extra in lists.dropFirst() {
            extra.items?.forEach { $0.list = oldest }
            extra.moves?.forEach { $0.list = oldest }
            context.delete(extra)
        }
        if context.hasChanges { save() }
        return oldest
    }

    // MARK: Changes

    /// Adds one item per line or comma-separated part, in the order typed. False if nothing was saved.
    /// An item that is on the list already moves to the end with its new text.
    @discardableResult
    func add(_ input: String) -> Bool {
        guard let list = activeList(), let store = list.objectID.persistentStore else { return false }
        let now = Date.now
        let texts = ItemName.withoutRepeats(ItemName.split(input))
        removeRepeats(of: texts)
        for (offset, text) in texts.enumerated() {
            let item = Item(context: context)
            context.assign(item, to: store)
            item.id = UUID()
            item.text = text
            item.category = knownCategory(of: text)
            // A second apart, so a drag in list mode has room between two items. See `ListState.reordered`.
            item.createdAt = now.addingTimeInterval(Double(offset))
            item.modifiedAt = now
            item.list = list
        }
        return save()
    }

    /// The item takes the first part. The other parts become new items right after it.
    func split(_ id: UUID, into parts: [String]) {
        let parts = ItemName.withoutRepeats(parts)
        guard let item = item(id), let first = parts.first, let list = item.list,
            let store = item.objectID.persistentStore
        else { return }
        removeRepeats(of: parts, except: id)
        let now = Date.now
        item.text = first
        item.category = knownCategory(of: first)
        item.modifiedAt = now
        for (offset, text) in parts.dropFirst().enumerated() {
            let part = Item(context: context)
            context.assign(part, to: store)
            part.id = UUID()
            part.text = text
            part.category = knownCategory(of: text)
            // A tenth of a second apart, so they stay before the next item, which was added at least a second later.
            part.createdAt = (item.createdAt ?? now).addingTimeInterval(Double(offset + 1) / 10)
            part.modifiedAt = now
            part.list = list
        }
        save()
    }

    /// Changes the text of an item in place. An empty text deletes the item, and commas make more items.
    func edit(_ row: Row, to text: String) {
        let parts = ItemName.split(text)
        if parts.isEmpty {
            delete([row.id])
        } else if parts != [row.text] {
            split(row.id, into: parts)
        }
    }

    /// Deletes the open items that `texts` repeat, and says which ones. See `repeated`.
    private func removeRepeats(of texts: [String], except kept: UUID? = nil) {
        let older = state.repeated(by: texts).filter { $0.id != kept }
        for row in older { item(row.id).map(context.delete) }
        if !older.isEmpty { repeated = older.map(\.name).joined(separator: ", ") }
    }

    func setTicked(_ id: UUID, _ ticked: Bool) { change(id) { $0.tickedAt = ticked ? .now : nil } }

    func later(_ id: UUID) { change(id) { $0.deferredAt = .now } }

    /// "New list": the open items leave the list together and show in the history as one archived list.
    /// The ticked items of the trip in progress leave too. They stay in the history as that trip.
    func archiveList() {
        let now = Date.now
        for row in state.rows {
            item(row.id).map { $0.archivedAt = now; $0.modifiedAt = now }
        }
        save()
    }

    func delete(_ ids: some Sequence<UUID>) {
        for id in ids { item(id).map(context.delete) }
        save()
    }

    /// List mode: a drag gives the item a new place. See `ListState.reordered`.
    func move(_ id: UUID, toCreatedAt date: Date) { change(id) { $0.createdAt = date } }

    func setCategory(_ id: UUID, _ category: String) {
        item(id)?.category = category
        save()
    }

    /// The section order of the list, for everyone who shares it. Nil goes back to the route of a typical supermarket.
    func setSections(_ sections: [GrailkaufCore.Category]?) {
        activeList()?.sections = sections?.map(\.rawValue).joined(separator: ",")
        save()
    }

    #if DEBUG
    /// Sends a record of each entity, with every field set, to the Development schema in iCloud, then deletes it.
    /// Only a Debug build talks to the Development environment.
    func uploadSchema() async throws {
        let container = container
        try await Task.detached { try container.initializeCloudKitSchema() }.value
    }
    #endif

    /// Records a manual drag on the order screen.
    func record(_ move: Move) {
        guard let list = activeList(), let store = list.objectID.persistentStore else { return }
        let stored = OrderMove(context: context)
        context.assign(stored, to: store)
        stored.key = move.key
        stored.after = move.after
        stored.date = move.date
        stored.list = list
        save()
    }

    /// Applies the ticks from the other device. For each item, the newer change wins.
    func apply(_ rows: [Row]) {
        for row in rows {
            guard let item = item(row.id), row.modifiedAt > (item.modifiedAt ?? .distantPast) else { continue }
            item.tickedAt = row.tickedAt
            item.deferredAt = row.deferredAt
            item.modifiedAt = row.modifiedAt
        }
        if context.hasChanges { save() }
    }

    /// The version of the given items on this device, also of items that left the current list.
    func rows(for ids: Set<UUID>) -> [Row] {
        entries.filter { ids.contains($0.id) }.map { Row($0) }
    }

    private func knownCategory(of text: String) -> String? {
        let key = ItemName.key(text)
        return entries.filter { $0.key == key && $0.category != nil }.max { $0.createdAt < $1.createdAt }?.category
    }

    private func change(_ id: UUID, _ edit: (Item) -> Void) {
        guard let item = item(id) else { return }
        edit(item)
        item.modifiedAt = .now
        save()
    }

    private func item(_ id: UUID) -> Item? {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            problem = error.localizedDescription
            return false
        }
    }
}

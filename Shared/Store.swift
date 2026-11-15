import CloudKit
import CoreData
import GrailkaufCore
import Observation

@objc(ShoppingList) final class ShoppingList: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var items: Set<Item>?
    @NSManaged var moves: Set<OrderMove>?
}

/// A line of the list. Ticked items are never removed: they are the purchase history the order and the
/// suggestions are learned from.
@objc(Item) final class Item: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var text: String?
    @NSManaged var category: String?
    @NSManaged var createdAt: Date?
    @NSManaged var modifiedAt: Date?
    @NSManaged var tickedAt: Date?
    @NSManaged var deferredAt: Date?
    @NSManaged var list: ShoppingList?

    var entry: Entry? {
        guard let id, let text, let createdAt else { return nil }
        return Entry(
            id: id, text: text, category: category, createdAt: createdAt, modifiedAt: modifiedAt,
            tickedAt: tickedAt, deferredAt: deferredAt)
    }
}

/// A manual drag on the order screen.
@objc(OrderMove) final class OrderMove: NSManagedObject {
    @NSManaged var key: String?
    @NSManaged var after: String?
    @NSManaged var date: Date?
    @NSManaged var list: ShoppingList?
}

/// The household's data: one list, kept in iCloud and shared through a CloudKit share.
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

    /// - Parameter ownsList: the iPhone creates the household's list; the Watch only ever reads and ticks.
    init(ownsList: Bool) {
        self.ownsList = ownsList
        container = NSPersistentCloudKitContainer(name: "Grailkauf", managedObjectModel: Self.makeModel())
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
        center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: container, queue: .main
        ) { [weak self] note in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = note.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                  event.type == .import, event.succeeded, let finished = event.endDate
            else { return }
            MainActor.assumeIsolated { self?.synced(at: finished) }
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

    /// Rebuilds everything the screens show. Also call when time alone may have changed the picture
    /// (a trip ends four hours after its last tick).
    // shortcut: reads and folds the whole history on every change; cache the order once a household has
    // tens of thousands of purchases.
    func refresh() {
        let now = Date.now
        let list = activeList()
        let entries = (list?.items ?? []).compactMap(\.entry)
        let moves = (list?.moves ?? []).compactMap { move -> Move? in
            guard let key = move.key, let date = move.date else { return nil }
            return Move(date: date, key: key, after: move.after)
        }
        let order = ListState.order(entries: entries, moves: moves, now: now)
        let state = ListState(entries: entries, order: order, lastSync: lastSync, now: now)
        if entries != self.entries { self.entries = entries }
        if order != self.order { self.order = order }
        if state != self.state { self.state = state }
        onChange()
    }

    /// The list this device works on: a list someone shared with us wins over our own.
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
        // A device that started a list before its first sync brought the existing one: fold it into the oldest.
        for extra in lists.dropFirst() {
            extra.items?.forEach { $0.list = oldest }
            extra.moves?.forEach { $0.list = oldest }
            context.delete(extra)
        }
        if context.hasChanges { save() }
        return oldest
    }

    // MARK: Changes

    /// Adds one item per line or comma-separated part, in the order typed.
    func add(_ input: String) {
        guard let list = activeList(), let store = list.objectID.persistentStore else { return }
        let now = Date.now
        for (offset, text) in ItemName.split(input).enumerated() {
            let item = Item(context: context)
            context.assign(item, to: store)
            item.id = UUID()
            item.text = text
            item.category = knownCategory(of: text)
            item.createdAt = now.addingTimeInterval(Double(offset) / 1000)
            item.modifiedAt = now
            item.list = list
        }
        save()
    }

    func rename(_ id: UUID, to text: String) {
        change(id) {
            $0.text = text
            $0.category = knownCategory(of: text)
        }
    }

    func setTicked(_ id: UUID, _ ticked: Bool) { change(id) { $0.tickedAt = ticked ? .now : nil } }

    func later(_ id: UUID) { change(id) { $0.deferredAt = .now } }

    func delete(_ id: UUID) {
        guard let item = item(id) else { return }
        context.delete(item)
        save()
    }

    func setCategory(_ id: UUID, _ category: String) {
        item(id)?.category = category
        save()
    }

    /// Records a manual drag: `key` now comes right after `after`, or first when nil.
    func move(_ key: String, after: String?) {
        guard let list = activeList(), let store = list.objectID.persistentStore else { return }
        let move = OrderMove(context: context)
        context.assign(move, to: store)
        move.key = key
        move.after = after
        move.date = .now
        move.list = list
        save()
    }

    /// Takes over ticks made on the other device. The newer change per item wins.
    func apply(_ rows: [Row]) {
        for row in rows {
            guard let item = item(row.id), row.modifiedAt > (item.modifiedAt ?? .distantPast) else { continue }
            item.tickedAt = row.tickedAt
            item.deferredAt = row.deferredAt
            item.modifiedAt = row.modifiedAt
        }
        if context.hasChanges { save() }
    }

    /// This device's version of the given items, whether they are still on the current list or not.
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

    private func save() {
        do {
            try context.save()
        } catch {
            context.rollback()
            problem = error.localizedDescription
        }
    }

    // MARK: Model

    /// Built in code so iPhone and Watch share one definition. CloudKit needs every attribute optional and
    /// every relationship to have an inverse.
    private static func makeModel() -> NSManagedObjectModel {
        func entity(_ name: String, _ attributes: [(String, NSAttributeDescription.AttributeType)]) -> NSEntityDescription {
            let entity = NSEntityDescription()
            entity.name = name
            entity.managedObjectClassName = name
            entity.properties = attributes.map { name, type in
                let attribute = NSAttributeDescription()
                attribute.name = name
                attribute.type = type
                attribute.isOptional = true
                return attribute
            }
            return entity
        }
        func own(_ list: NSEntityDescription, _ children: NSEntityDescription, as name: String) {
            let toMany = NSRelationshipDescription()
            toMany.name = name
            toMany.destinationEntity = children
            toMany.deleteRule = .cascadeDeleteRule
            toMany.isOptional = true
            let toOne = NSRelationshipDescription()
            toOne.name = "list"
            toOne.destinationEntity = list
            toOne.maxCount = 1
            toOne.deleteRule = .nullifyDeleteRule
            toOne.isOptional = true
            toMany.inverseRelationship = toOne
            toOne.inverseRelationship = toMany
            list.properties.append(toMany)
            children.properties.append(toOne)
        }
        let list = entity("ShoppingList", [("id", .uuid), ("createdAt", .date)])
        let item = entity("Item", [
            ("id", .uuid), ("text", .string), ("category", .string), ("createdAt", .date), ("modifiedAt", .date),
            ("tickedAt", .date), ("deferredAt", .date),
        ])
        let move = entity("OrderMove", [("key", .string), ("after", .string), ("date", .date)])
        own(list, item, as: "items")
        own(list, move, as: "moves")
        let model = NSManagedObjectModel()
        model.entities = [list, item, move]
        return model
    }
}

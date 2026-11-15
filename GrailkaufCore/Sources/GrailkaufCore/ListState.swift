import Foundation

/// One line someone typed, current or long bought. Mirrors the stored item.
public struct Entry: Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var category: String?
    public var createdAt: Date
    public var modifiedAt: Date
    public var tickedAt: Date?
    public var deferredAt: Date?
    public let key: String

    public init(
        id: UUID = UUID(), text: String, category: String? = nil, createdAt: Date, modifiedAt: Date? = nil,
        tickedAt: Date? = nil, deferredAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.tickedAt = tickedAt
        self.deferredAt = deferredAt
        self.key = ItemName.key(text)
    }

    /// Pushed back with "later" and bought afterwards: its tick says nothing about the route.
    var wasDeferred: Bool {
        guard let deferredAt, let tickedAt else { return false }
        return tickedAt >= deferredAt && tickedAt.timeIntervalSince(deferredAt) < OrderLearning.tripGap
    }
}

/// One line of the current list as the screens show it. This is also what iPhone and Watch exchange.
public struct Row: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    /// As typed: "2 Milch".
    public var text: String
    /// Cleaned: "Milch".
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var tickedAt: Date?
    public var deferredAt: Date?
    /// Position in the learned order. Negative: no position yet, shown in the "New" group.
    public var sort: Double
    /// Placed by its guessed category, not by experience.
    public var guessed: Bool

    public var isNew: Bool { sort < 0 }

    public init(_ entry: Entry, sort: Double = -1, guessed: Bool = false) {
        id = entry.id
        text = entry.text
        name = ItemName.display(entry.text)
        createdAt = entry.createdAt
        modifiedAt = entry.modifiedAt
        tickedAt = entry.tickedAt
        deferredAt = entry.deferredAt
        self.sort = sort
        self.guessed = guessed
    }

    public func isDeferred(now: Date) -> Bool {
        deferredAt.map { now.timeIntervalSince($0) < OrderLearning.tripGap } ?? false
    }
}

/// The current list: everything not bought yet plus what was ticked on the trip still in progress.
public struct ListState: Codable, Equatable, Sendable {
    public var rows: [Row] = []
    /// Last successful iCloud sync of the device this state came from.
    public var lastSync: Date?

    public init(rows: [Row] = [], lastSync: Date? = nil) {
        self.rows = rows
        self.lastSync = lastSync
    }

    /// Builds the current list from the full history, placing every open item in the learned order.
    public init(entries: [Entry], moves: [Move], lastSync: Date? = nil, now: Date) {
        self.init(entries: entries, order: Self.order(entries: entries, moves: moves, now: now), lastSync: lastSync, now: now)
    }

    public init(entries: [Entry], order: [String], lastSync: Date? = nil, now: Date) {
        let index = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        var categoryOf: [String: String] = [:]
        for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let category = entry.category { categoryOf[entry.key] = category }
        }
        var lastOfCategory: [String: Int] = [:]
        for (key, position) in index {
            if let category = categoryOf[key] { lastOfCategory[category] = max(lastOfCategory[category] ?? -1, position) }
        }

        func place(_ entry: Entry) -> (sort: Double, guessed: Bool) {
            if let position = index[entry.key] { return (Double(position), false) }
            if let position = Self.borrowed(entry.key, from: index) { return (Double(position) + 0.5, false) }
            if let category = entry.category ?? categoryOf[entry.key], category != Category.other.rawValue,
               let position = lastOfCategory[category] {
                return (Double(position) + 0.5, true)
            }
            return (-1, false)
        }

        let tripStart = Self.openTripStart(ticks: entries.compactMap(\.tickedAt), now: now)
        self.lastSync = lastSync
        self.rows = entries
            .filter { entry in entry.tickedAt.map { tick in tripStart.map { tick >= $0 } ?? false } ?? true }
            .map { entry in
                let placement = place(entry)
                return Row(entry, sort: placement.sort, guessed: placement.guessed)
            }
    }

    /// The learned order of every name bought on a finished trip.
    public static func order(entries: [Entry], moves: [Move], now: Date) -> [String] {
        let ticks = entries.compactMap { entry -> (key: String, at: Date)? in
            guard let at = entry.tickedAt, !entry.wasDeferred else { return nil }
            return (entry.key, at)
        }
        // A trip in progress must not reshuffle the list under the shopper's thumb.
        let finished = OrderLearning.trips(from: ticks).filter { now.timeIntervalSince($0.date) > OrderLearning.tripGap }
        return OrderLearning.order(trips: finished, moves: moves)
    }

    /// "bio milch" has no position of its own, so it takes the one of "milch".
    private static func borrowed(_ key: String, from index: [String: Int]) -> Int? {
        let words = key.split(separator: " ")
        for length in stride(from: words.count - 1, to: 0, by: -1) {
            for start in 0...(words.count - length) {
                if let position = index[words[start..<start + length].joined(separator: " ")] { return position }
            }
        }
        return nil
    }

    /// When the trip in progress began, or nil if the last tick is more than a trip gap ago.
    static func openTripStart(ticks: [Date], now: Date) -> Date? {
        let newestFirst = ticks.sorted(by: >)
        guard var start = newestFirst.first, now.timeIntervalSince(start) <= OrderLearning.tripGap else { return nil }
        for tick in newestFirst.dropFirst() {
            guard start.timeIntervalSince(tick) <= OrderLearning.tripGap else { break }
            start = tick
        }
        return start
    }

    // MARK: What the screens show

    /// List mode: open items in the order they were added.
    public var todo: [Row] {
        rows.filter { $0.tickedAt == nil }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Shop mode: "New" items first, then the learned order, items pushed back with "later" last.
    /// `lingering` keeps just-ticked rows in place while they fade out.
    public func shop(now: Date, lingering: Set<UUID> = []) -> [Row] {
        rows.filter { $0.tickedAt == nil || lingering.contains($0.id) }.sorted { a, b in
            let aLater = a.isDeferred(now: now), bLater = b.isDeferred(now: now)
            if aLater != bLater { return bLater }
            if aLater { return a.deferredAt! < b.deferredAt! }
            return (a.sort, a.createdAt) < (b.sort, b.createdAt)
        }
    }

    /// Ticked on the trip in progress, most recent first.
    public func done(now: Date) -> [Row] {
        guard let start = Self.openTripStart(ticks: rows.compactMap(\.tickedAt), now: now) else { return [] }
        return rows.filter { ($0.tickedAt ?? .distantPast) >= start }.sorted { $0.tickedAt! > $1.tickedAt! }
    }

    // MARK: Changes

    public mutating func tick(_ id: UUID, at now: Date) { change(id, now) { $0.tickedAt = now } }
    public mutating func untick(_ id: UUID, at now: Date) { change(id, now) { $0.tickedAt = nil } }
    public mutating func later(_ id: UUID, at now: Date) { change(id, now) { $0.deferredAt = now } }

    private mutating func change(_ id: UUID, _ now: Date, _ edit: (inout Row) -> Void) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        edit(&rows[index])
        rows[index].modifiedAt = now
    }

    /// Our rows, each taking the other side's content when that was changed more recently. Placement stays ours.
    public func updated(from other: [Row]) -> ListState {
        let theirs = Dictionary(other.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var result = self
        result.rows = rows.map { mine in
            guard var newer = theirs[mine.id], newer.modifiedAt > mine.modifiedAt else { return mine }
            newer.sort = mine.sort
            newer.guessed = mine.guessed
            return newer
        }
        return result
    }
}

/// Hidden groups used only to place an item the learned order has not seen yet.
public enum Category: String, CaseIterable, Sendable {
    case produce, bakery, meat, fish, cheese, dairy, frozen, tins, pasta, baking, spices, breakfast, sweets
    case softDrinks, alcohol, toiletries, household, baby, pets, other
}

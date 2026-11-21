import Foundation

/// One line that someone typed, open or bought. It mirrors the stored item.
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

    /// True if the item was moved back with "later" and bought after that. Its tick then says nothing about the route.
    var wasDeferred: Bool {
        guard let deferredAt, let tickedAt else { return false }
        return tickedAt >= deferredAt && tickedAt.timeIntervalSince(deferredAt) < OrderLearning.tripGap
    }
}

/// One line of the current list as the screens show it. The phone and the Watch exchange these rows.
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
    /// The raw value of a `Category`. Nil until the language model sorts the item.
    public var category: String?

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
        category = entry.category
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
                var row = Row(entry, sort: placement.sort, guessed: placement.guessed)
                row.category = entry.category ?? categoryOf[entry.key]
                return row
            }
    }

    /// The learned order of every name bought on a finished trip.
    public static func order(entries: [Entry], moves: [Move], now: Date) -> [String] {
        let ticks = entries.compactMap { entry -> (key: String, at: Date)? in
            guard let at = entry.tickedAt, !entry.wasDeferred else { return nil }
            return (entry.key, at)
        }
        // A trip in progress must not change the order while the user shops.
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

    /// The open rows that `texts` would add a second time. "2 Milch" repeats "Milch".
    public func repeated(by texts: [String]) -> [Row] {
        let keys = Set(texts.map(ItemName.key))
        return todo.filter { keys.contains(ItemName.key($0.text)) }
    }

    /// List mode: a drag moves the row at `source` to `destination`, counted as SwiftUI's `onMove` counts.
    /// The row gets a `createdAt` between its new neighbours, so `todo` keeps the new order. Nil if nothing moves.
    // shortcut: iCloud keeps dates to the millisecond, so many drags into one gap can tie two rows. Add a stored
    // position if users report that.
    public func reordered(from source: Int, to destination: Int) -> (id: UUID, createdAt: Date)? {
        var rows = todo
        guard rows.indices.contains(source), destination != source, destination != source + 1 else { return nil }
        let row = rows.remove(at: source)
        let index = min(destination > source ? destination - 1 : destination, rows.count)
        let before = index > 0 ? rows[index - 1].createdAt : nil
        let after = index < rows.count ? rows[index].createdAt : nil
        switch (before, after) {
        case let (before?, after?): return (row.id, before + after.timeIntervalSince(before) / 2)
        case let (before?, nil): return (row.id, before + 1)
        case let (nil, after?): return (row.id, after - 1)
        case (nil, nil): return nil
        }
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

    /// The list on the Watch. The Watch has two sources: its own cloud copy and the list from the phone.
    /// The source with the later cloud sync decides which items are on the list.
    /// For each item, the newer change wins.
    /// - Parameters:
    ///   - own: the list from the Watch's own store. Nil if that store is empty.
    ///   - ownVersions: the Watch's own version of the phone's items, also of items it no longer lists.
    public static func onWatch(phone: ListState?, own: ListState?, ownVersions: [Row]) -> ListState {
        var merged: ListState
        if let phone, own == nil || (phone.lastSync ?? .distantPast) >= (own?.lastSync ?? .distantPast) {
            merged = phone.updated(from: ownVersions)
        } else {
            merged = (own ?? ListState()).updated(from: phone?.rows ?? [])
        }
        merged.lastSync = [phone?.lastSync, own?.lastSync].compactMap(\.self).max()
        return merged
    }

    /// Our rows. Each row takes the content of the other side if that content is newer. The position stays ours.
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

/// Supermarket sections. They place an item that the learned order does not know yet, and group the grid view.
/// The cases follow the route through a typical supermarket. The grid view shows the sections in this order.
public enum Category: String, CaseIterable, Sendable {
    case produce, spices, tins, household, toiletries, baby, sweets, meat, fish, breakfast, bakery, frozen
    case baking, pasta, cheese, dairy, pets, softDrinks, alcohol, other

    /// Reads the answer of the language model. An answer that is not on the list is `.other`.
    public init(answer: String) {
        let word = answer.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        self = Self.allCases.first { $0.rawValue.lowercased() == word } ?? .other
    }
}

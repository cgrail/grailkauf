import Foundation

/// One past shopping trip or archived list as the history shows it.
public struct PastTrip: Sendable {
    /// The last tick of the trip, or when "New list" archived the list.
    public var date: Date
    /// True for a list that "New list" archived, false for a shopping trip.
    public var archived = false
    /// The texts of the bought items in tick order, each with its latest text. True if it is on the list now.
    public var items: [(text: String, onList: Bool)]
}

public enum Suggestions {
    /// All trips and archived lists, newest first.
    public static func history(entries: [Entry]) -> [PastTrip] {
        let onList = Set(entries.filter(\.isOpen).map(\.key))
        let latest = Dictionary(
            entries.sorted { $0.createdAt < $1.createdAt }.map { ($0.key, $0.text) }, uniquingKeysWith: { $1 })
        let ticks = entries.compactMap { entry in entry.tickedAt.map { (key: entry.key, at: $0) } }
        let trips = OrderLearning.trips(from: ticks).map { trip in
            PastTrip(date: trip.date, items: trip.keys.map { (latest[$0]!, onList.contains($0)) })
        }
        let archived = Dictionary(grouping: entries.filter { $0.archivedAt != nil }, by: \.archivedAt!).map { date, list in
            PastTrip(
                date: date, archived: true,
                items: list.sorted { $0.createdAt < $1.createdAt }.map { ($0.text, onList.contains($0.key)) })
        }
        return (trips + archived).sorted { $0.date > $1.date }
    }

    /// Items of past trips and archived lists that are not on the list now. The item in the most lists comes first.
    /// Each item has the text of its newest list. If two items are in as many lists, the more recent one comes first.
    public static func fromPastLists(entries: [Entry], limit: Int = 10) -> [String] {
        var seen: [String: (text: String, count: Int, rank: Int)] = [:]
        for list in history(entries: entries) {
            var counted = Set<String>()
            for item in list.items where !item.onList && counted.insert(ItemName.key(item.text)).inserted {
                let key = ItemName.key(item.text)
                let old = seen[key]
                seen[key] = (old?.text ?? item.text, (old?.count ?? 0) + 1, old?.rank ?? seen.count)
            }
        }
        return seen.values.sorted { ($1.count, $0.rank) < ($0.count, $1.rank) }.prefix(limit).map(\.text)
    }

    /// The texts of the items that are due again, most regular first.
    /// An item is due when most of its usual gap between purchases is over.
    /// The rhythm of an item is known after three purchases.
    public static func due(entries: [Entry], now: Date) -> [String] {
        let onList = Set(entries.filter(\.isOpen).map(\.key))
        var due: [(text: String, count: Int)] = []
        for (key, purchases) in Dictionary(grouping: entries.filter { $0.tickedAt != nil }, by: \.key)
        where !onList.contains(key) {
            let sorted = purchases.sorted { $0.tickedAt! < $1.tickedAt! }
            var days: [Date] = []
            for purchase in sorted where days.last.map({ purchase.tickedAt!.timeIntervalSince($0) > 86_400 }) ?? true {
                days.append(purchase.tickedAt!)
            }
            guard days.count >= 3,
                  let rhythm = OrderLearning.median(zip(days.dropFirst(), days).map { $0.timeIntervalSince($1) })
            else { continue }
            let elapsed = now.timeIntervalSince(days.last!)
            // 0.7, not 0.75: people write the list shortly before the shop. A four-week item must then be
            // due a little less than three weeks after its last purchase.
            // After four rhythms, the household no longer buys the item.
            if elapsed >= 0.7 * rhythm, elapsed <= 4 * rhythm { due.append((sorted.last!.text, days.count)) }
        }
        return due.sorted { ($1.count, $0.text) < ($0.count, $1.text) }.map(\.text)
    }

    /// Past items matching what is being typed, most used first.
    public static func completions(for fragment: String, entries: [Entry], limit: Int = 5) -> [String] {
        let needle = fragment.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        let onList = Set(entries.filter(\.isOpen).map(\.key))
        var known: [String: (text: String, latest: Date, count: Int)] = [:]
        for entry in entries where entry.text.lowercased().contains(needle) && !onList.contains(entry.key) {
            let seen = known[entry.key]
            let isLatest = seen.map { entry.createdAt > $0.latest } ?? true
            known[entry.key] = (
                isLatest ? entry.text : seen!.text, isLatest ? entry.createdAt : seen!.latest, (seen?.count ?? 0) + 1
            )
        }
        return known.values.sorted { ($1.count, $0.text) < ($0.count, $1.text) }.prefix(limit).map(\.text)
    }
}

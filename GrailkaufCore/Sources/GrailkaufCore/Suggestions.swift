import Foundation

public enum Suggestions {
    /// The texts of the items that are due again, most regular first.
    /// An item is due when most of its usual gap between purchases is over.
    /// The rhythm of an item is known after three purchases.
    public static func due(entries: [Entry], now: Date) -> [String] {
        let onList = Set(entries.filter { $0.tickedAt == nil }.map(\.key))
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
        let onList = Set(entries.filter { $0.tickedAt == nil }.map(\.key))
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

import Foundation

extension Grid {
    /// The grid on the Mac: `moved` lands among `rows`, the items of a section, before `target` or at the end.
    /// - Returns: the keys of the section's items in their new order.
    public static func keys(dropping moved: Row, before target: Row?, in rows: [Row]) -> [String] {
        var rows = rows.filter { $0.id != moved.id }
        rows.insert(moved, at: target.flatMap { target in rows.firstIndex { $0.id == target.id } } ?? rows.count)
        return rows.map { ItemName.key($0.text) }
    }
}

extension OrderLearning {
    /// The grid on the Mac: `keys` are the items of one section in the order of the drop, with `moved` among them.
    /// The moved item and each item that the order lacks take their place there. The others keep what they learned.
    public static func moves(arranging keys: [String], moved: String, order: [String], at date: Date) -> [Move] {
        let order = order.filter { $0 != moved }
        let known = Set(order)
        var placed: [(key: String, after: String?)] = []
        var previous: String?
        for (index, key) in keys.enumerated() {
            defer { previous = key }
            guard !known.contains(key) else { continue }
            if let previous {
                placed.append((key, previous))
            } else if let next = keys[index...].first(where: known.contains), let at = order.firstIndex(of: next) {
                // First in the section: just before the first item that the order knows.
                placed.append((key, at > 0 ? order[at - 1] : nil))
            } else {
                placed.append((key, order.last))
            }
        }
        // A second apart, the last at `date`: the order applies moves by date.
        return placed.enumerated().map { Move(date: date - Double(placed.count - 1 - $0), key: $1.key, after: $1.after) }
    }
}

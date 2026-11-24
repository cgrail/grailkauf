import Foundation

/// One line of the sections view on the Mac: a section header, or an item below it.
public enum Line: Equatable, Identifiable, Sendable {
    case section(Category)
    case item(Row)

    public var id: String {
        switch self {
        case .section(let section): "section." + section.rawValue
        case .item(let row): row.id.uuidString
        }
    }

    public var section: Category? { if case .section(let section) = self { section } else { nil } }
    public var row: Row? { if case .item(let row) = self { row } else { nil } }
}

/// What a drag in the sections view changes.
public enum Drop: Equatable, Sendable {
    /// A header moved: the new order of all sections.
    case sections([Category])
    /// An item moved: the section that it is in now, and the keys of that section's items in their new order.
    case item(Row, section: Category, keys: [String])
}

extension Grid {
    /// Every section of `order`, each followed by its rows in the order of `rows`.
    /// An empty section shows too, so an item can go there.
    public static func lines(_ rows: [Row], order: [Category]) -> [Line] {
        let groups = Dictionary(grouping: rows) { Category(rawValue: $0.category ?? "") ?? .other }
        return order.flatMap { [Line.section($0)] + (groups[$0] ?? []).map(Line.item) }
    }

    /// The line at `source` lands before index `destination`, counted as SwiftUI's `onMove` counts.
    /// Nil if nothing changes.
    public static func drop(_ lines: [Line], from source: Int, to destination: Int) -> Drop? {
        guard lines.indices.contains(source), destination != source, destination != source + 1,
              lines.contains(where: { $0.section != nil })
        else { return nil }
        var moved = lines
        let line = moved.remove(at: source)
        var index = min(destination > source ? destination - 1 : destination, moved.count)
        // Above the first header, an item goes to the top of the first section.
        if line.row != nil, !moved[..<index].contains(where: { $0.section != nil }) {
            index = moved.firstIndex { $0.section != nil }! + 1
        }
        moved.insert(line, at: index)
        guard let row = line.row else {
            let order = moved.compactMap(\.section)
            return order == lines.compactMap(\.section) ? nil : .sections(order)
        }
        let header = moved[..<index].lastIndex { $0.section != nil }!
        let end = moved[(index + 1)...].firstIndex { $0.section != nil } ?? moved.count
        let keys = moved[(header + 1)..<end].compactMap(\.row).map { ItemName.key($0.text) }
        return .item(row, section: moved[header].section!, keys: keys)
    }
}

extension OrderLearning {
    /// The sections view: `keys` are the items of one section in the order of the drop, with `moved` among them.
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

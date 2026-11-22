import Foundation

/// One shopping trip: the item names in the order they were ticked.
public struct Trip: Equatable, Sendable {
    public var date: Date
    public var keys: [String]

    public init(date: Date, keys: [String]) {
        self.date = date
        self.keys = keys
    }
}

/// A manual drag on the order screen. `key` now comes directly after `after`. Nil puts it first.
public struct Move: Equatable, Sendable {
    public var date: Date
    public var key: String
    public var after: String?

    public init(date: Date, key: String, after: String?) {
        self.date = date
        self.key = key
        self.after = after
    }
}

public enum OrderLearning {
    /// Ticks further apart than this belong to different trips.
    public static let tripGap: TimeInterval = 4 * 3600

    /// Groups ticks into trips. A name ticked twice in one trip counts once.
    public static func trips(from ticks: [(key: String, at: Date)]) -> [Trip] {
        var trips: [Trip] = []
        for tick in ticks.sorted(by: { $0.at < $1.at }) {
            if let last = trips.last, tick.at.timeIntervalSince(last.date) <= tripGap {
                trips[trips.count - 1].date = tick.at
                if !last.keys.contains(tick.key) { trips[trips.count - 1].keys.append(tick.key) }
            } else {
                trips.append(Trip(date: tick.at, keys: [tick.key]))
            }
        }
        return trips
    }

    /// The learned order of all known names.
    ///
    /// Each trip gives the positions of its items back to them in tick order.
    /// An item takes the median of what its last `window` trips say.
    /// So one chaotic trip changes nothing, and a rearranged store wins after three trips.
    /// A manual move applies at once. The item then forgets the trips before the move.
    public static func order(trips: [Trip], moves: [Move], window: Int = 5) -> [String] {
        enum Event { case trip(Trip), move(Move) }
        let events = (trips.map { ($0.date, Event.trip($0)) } + moves.map { ($0.date, Event.move($0)) })
            .sorted { $0.0 < $1.0 }

        var order: [String] = []
        var forgetBefore: [String: Date] = [:]
        var seen: [Trip] = []
        for (_, event) in events {
            switch event {
            case .move(let move):
                order.removeAll { $0 == move.key }
                let index = move.after.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
                order.insert(move.key, at: index)
                forgetBefore[move.key] = move.date
            case .trip(let trip):
                insertNew(trip.keys, into: &order)
                seen.append(trip)
                order = relearn(order, from: seen, forgetBefore: forgetBefore, window: window)
            }
        }
        return order
    }

    /// A new name goes directly after the item that was ticked before it.
    private static func insertNew(_ keys: [String], into order: inout [String]) {
        for (i, key) in keys.enumerated() where !order.contains(key) {
            if i > 0, let previous = order.firstIndex(of: keys[i - 1]) {
                order.insert(key, at: previous + 1)
            } else if let known = keys[(i + 1)...].first(where: order.contains), let next = order.firstIndex(of: known) {
                order.insert(key, at: next)
            } else {
                order.append(key)
            }
        }
    }

    private static func relearn(
        _ order: [String], from trips: [Trip], forgetBefore: [String: Date], window: Int
    ) -> [String] {
        let index = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, Double($0)) })
        var said: [String: [Double]] = [:]
        for trip in trips.reversed() {
            let keys = trip.keys.filter { (forgetBefore[$0] ?? .distantPast) < trip.date }
            let slots = keys.compactMap { index[$0] }.sorted()
            for (key, slot) in zip(keys, slots) where said[key, default: []].count < window {
                said[key, default: []].append(slot)
            }
        }
        let position = index.mapValues { $0 }.merging(said.compactMapValues(median)) { _, learned in learned }
        return order.sorted { (position[$0]!, index[$0]!) < (position[$1]!, index[$1]!) }
    }

    /// Translates a drag on the order screen into a move.
    /// The item lands before index `destination` of `order`. Nil if the item stays where it is.
    public static func move(in order: [String], from source: Int, to destination: Int, at date: Date) -> Move? {
        guard order.indices.contains(source), destination != source, destination != source + 1 else { return nil }
        let others = order.enumerated().filter { $0.offset != source }.map(\.element)
        let landed = destination > source ? destination - 1 : destination
        return Move(date: date, key: order[source], after: landed > 0 ? others[landed - 1] : nil)
    }

    /// Translates a drag on the order screen, which shows `order` and then `new`, the names the order lacks.
    /// The new names down to the drop place join the order first, so the moved item has its neighbour there.
    public static func moves(order: [String], new: [String], from source: Int, to destination: Int, at date: Date) -> [Move] {
        let shown = order + new
        guard let move = move(in: shown, from: source, to: destination, at: date) else { return [] }
        let end = move.after.flatMap(shown.firstIndex(of:)).map { $0 + 1 } ?? 0
        let joining = shown[order.count..<max(order.count, end)].filter { $0 != move.key }
        // A second apart and before the drag: the order applies moves by date.
        var after = order.last
        let joins = joining.enumerated().map { offset, key in
            defer { after = key }
            return Move(date: date - Double(joining.count - offset), key: key, after: after)
        }
        return joins + [move]
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}

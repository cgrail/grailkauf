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

/// A manual drag on the order screen: `key` was placed right after `after` (nil = at the very top).
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
    /// Each trip says where its items belong by handing the positions they currently occupy back to them in
    /// tick order. An item takes the median of what its last `window` trips say, so a single chaotic trip changes
    /// nothing and a rearranged store wins after three trips. A manual move applies at once and makes the
    /// item forget the trips before it.
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

    /// A name seen for the first time goes right after the item ticked before it.
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

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}

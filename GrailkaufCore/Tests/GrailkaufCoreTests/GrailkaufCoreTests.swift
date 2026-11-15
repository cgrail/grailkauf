import Foundation
import Testing
@testable import GrailkaufCore

private let friday = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 3600
private let week: TimeInterval = 7 * 24 * 3600

/// A finished trip `weeksAgo` weeks before `friday`, ticking `names` one minute apart.
private func trip(_ weeksAgo: Double, _ names: [String]) -> [Entry] {
    let start = friday - weeksAgo * week
    return names.enumerated().map { index, name in
        Entry(text: name, createdAt: start - hour, tickedAt: start + Double(index) * 60)
    }
}

@Suite struct ItemNameTests {
    @Test(arguments: [
        ("2 Milch", "milch"), ("Milch 3,5%", "milch"), ("1 l Milch", "milch"), ("Milch", "milch"),
        ("500g Hackfleisch", "hackfleisch"), ("2x Coke Zero", "coke zero"), ("eine Dose Mais", "mais"),
        ("Bio Milch", "bio milch"), ("Äpfel", "äpfel"), ("  Eier  (6er) ", "eier"), ("2", "2"),
    ])
    func key(text: String, expected: String) {
        #expect(ItemName.key(text) == expected)
    }

    @Test func displayKeepsCapitalisation() {
        #expect(ItemName.display("2 Coke Zero") == "Coke Zero")
    }

    @Test func splitsOnCommasAndLinesButNotInsideNumbers() {
        #expect(ItemName.split("Milch 3,5%, Eier,Butter\nBrot\n\n") == ["Milch 3,5%", "Eier", "Butter", "Brot"])
    }
}

@Suite struct OrderLearningTests {
    private func trips(_ sequences: [String]...) -> [Trip] {
        sequences.enumerated().map { Trip(date: friday + Double($0) * week, keys: $1) }
    }

    @Test func firstTripIsTheOrder() {
        #expect(OrderLearning.order(trips: trips(["a", "b", "c"]), moves: []) == ["a", "b", "c"])
    }

    @Test func oneChaoticTripChangesNothing() {
        let usual = ["a", "b", "c", "d"]
        let learned = OrderLearning.order(trips: trips(usual, usual, usual, usual, ["d", "a", "c", "b"]), moves: [])
        #expect(learned == usual)
    }

    @Test func rearrangedStoreWinsAfterThreeTrips() {
        let old = ["a", "b", "c", "d"], new = ["d", "a", "b", "c"]
        #expect(OrderLearning.order(trips: trips(old, old, old, old, old, new, new), moves: []) == old)
        #expect(OrderLearning.order(trips: trips(old, old, old, old, old, new, new, new), moves: []) == new)
    }

    @Test func newItemGoesAfterTheOneTickedBeforeIt() {
        let usual = ["a", "b", "c"]
        #expect(OrderLearning.order(trips: trips(usual, usual, ["a", "x", "b", "c"]), moves: []) == ["a", "x", "b", "c"])
        #expect(OrderLearning.order(trips: trips(usual, ["x", "b"]), moves: []) == ["a", "x", "b", "c"])
    }

    @Test func partialTripsKeepUnboughtItemsInPlace() {
        let learned = OrderLearning.order(trips: trips(["a", "b", "c", "d", "e"], ["b", "d"], ["a", "e"]), moves: [])
        #expect(learned == ["a", "b", "c", "d", "e"])
    }

    @Test func manualMoveAppliesAtOnceAndCanBeRelearned() {
        let usual = ["a", "b", "c", "d"]
        let history = trips(usual, usual, usual)
        let move = Move(date: history[2].date + hour, key: "d", after: nil)
        #expect(OrderLearning.order(trips: history, moves: [move]) == ["d", "a", "b", "c"])

        let moveBack = Move(date: history[2].date + 2 * hour, key: "d", after: "b")
        #expect(OrderLearning.order(trips: history, moves: [move, moveBack]) == ["a", "b", "d", "c"])

        // Trips after the move teach the item again; the ones before it are forgotten.
        let later = (3...5).map { Trip(date: friday + Double($0) * week, keys: usual) }
        #expect(OrderLearning.order(trips: history + later, moves: [move]) == usual)
    }

    @Test func ticksGroupIntoTripsByGap() {
        let ticks: [(key: String, at: Date)] = [
            ("a", friday), ("b", friday + 60), ("a", friday + 120), ("c", friday + 5 * hour),
        ]
        #expect(OrderLearning.trips(from: ticks).map(\.keys) == [["a", "b"], ["c"]])
    }
}

@Suite struct ListStateTests {
    private let history = trip(3, ["Äpfel", "Milch", "Pfeffer", "Cola"]) + trip(2, ["Äpfel", "Milch", "Pfeffer", "Cola"])

    private func state(_ open: [Entry], now: Date = friday) -> ListState {
        ListState(entries: history + open, moves: [], now: now)
    }

    @Test func shopModeFollowsTheLearnedOrder() {
        let open = ["Cola", "2 Milch", "Äpfel"].enumerated().map {
            Entry(text: $1, createdAt: friday - hour + Double($0))
        }
        let list = state(open)
        #expect(list.todo.map(\.text) == ["Cola", "2 Milch", "Äpfel"])
        #expect(list.shop(now: friday).map(\.name) == ["Äpfel", "Milch", "Cola"])
    }

    @Test func unknownItemsBorrowGuessOrGoToNew() {
        var tagged = history
        tagged[2].category = Category.spices.rawValue  // Pfeffer
        let open = [
            Entry(text: "Bio Milch", createdAt: friday - 4),
            Entry(text: "Kurkuma", category: Category.spices.rawValue, createdAt: friday - 3),
            Entry(text: "Tahini", createdAt: friday - 2),
            Entry(text: "Batterien", category: Category.other.rawValue, createdAt: friday - 1),
        ]
        let list = ListState(entries: tagged + open, moves: [], now: friday)
        let shop = list.shop(now: friday)
        #expect(shop.map(\.name) == ["Tahini", "Batterien", "Bio Milch", "Kurkuma"])
        #expect(shop.map(\.isNew) == [true, true, false, false])
        #expect(shop.map(\.guessed) == [false, false, false, true])
    }

    @Test func tickedItemsStayForTheTripThenLeave() {
        let ticked = Entry(text: "Milch", createdAt: friday - hour, tickedAt: friday)
        let open = Entry(text: "Cola", createdAt: friday - hour)
        let during = state([ticked, open], now: friday + hour)
        #expect(during.done(now: friday + hour).map(\.name) == ["Milch"])
        #expect(during.todo.map(\.name) == ["Cola"])

        let after = state([ticked, open], now: friday + 5 * hour)
        #expect(after.rows.map(\.name) == ["Cola"])
    }

    @Test func tripInProgressDoesNotReorder() {
        let ticking = [
            Entry(text: "Cola", createdAt: friday - hour, tickedAt: friday),
            Entry(text: "Milch", createdAt: friday - hour, tickedAt: friday + 60),
        ]
        #expect(ListState.order(entries: history + ticking, moves: [], now: friday + hour).first == "äpfel")
    }

    @Test func laterPushesToTheEndAndIsIgnoredForLearning() {
        var list = state(["Äpfel", "Milch", "Cola"].map { Entry(text: $0, createdAt: friday - hour) })
        let apples = list.shop(now: friday)[0]
        list.later(apples.id, at: friday)
        #expect(list.shop(now: friday).map(\.name) == ["Milch", "Cola", "Äpfel"])

        let deferred = Entry(text: "Äpfel", createdAt: friday - hour, tickedAt: friday + 600, deferredAt: friday)
        let others = [
            Entry(text: "Milch", createdAt: friday - hour, tickedAt: friday + 60),
            Entry(text: "Cola", createdAt: friday - hour, tickedAt: friday + 120),
        ]
        let order = ListState.order(entries: history + others + [deferred], moves: [], now: friday + week)
        #expect(order.first == "äpfel")
    }

    @Test func newerChangeWinsPerRowAndPlacementStays() {
        var phone = state([Entry(text: "Milch", createdAt: friday - hour), Entry(text: "Cola", createdAt: friday - hour)])
        var watch = phone
        watch.rows[0].sort = 99
        watch.tick(watch.rows[0].id, at: friday + 10)
        phone.tick(phone.rows[1].id, at: friday + 20)

        let merged = phone.updated(from: watch.rows)
        #expect(merged.rows.map { $0.tickedAt != nil } == [true, true])
        #expect(merged.rows[0].sort == phone.rows[0].sort)
        #expect(watch.updated(from: phone.rows).rows.map { $0.tickedAt != nil } == [true, true])
    }
}

@Suite struct SuggestionsTests {
    @Test func weeklyAndMonthlyItemsAreDueOnTheirRhythm() {
        let weekly = (1...4).flatMap { trip(Double($0), ["Milch"]) }
        let monthly = trip(11, ["Kaffee"]) + trip(7, ["Kaffee"]) + trip(3, ["Kaffee"])
        let recent = trip(9, ["Salz"]) + trip(5, ["Salz"]) + trip(1, ["Salz"])
        let once = trip(1, ["Tahini"])
        let dropped = (20...23).flatMap { trip(Double($0), ["Chips"]) }
        let entries = weekly + monthly + recent + once + dropped
        let now = friday - 600

        #expect(Suggestions.due(entries: entries, now: now) == ["Milch", "Kaffee"])

        let alreadyListed = entries + [Entry(text: "3 Milch", createdAt: now)]
        #expect(Suggestions.due(entries: alreadyListed, now: now) == ["Kaffee"])
    }

    @Test func completionsPreferWhatIsBoughtMost() {
        let entries = trip(3, ["Milch", "Mehl"]) + trip(2, ["2 Milch"]) + [Entry(text: "Mais", createdAt: friday)]
        #expect(Suggestions.completions(for: "m", entries: entries) == ["2 Milch", "Mehl"])
        #expect(Suggestions.completions(for: " ", entries: entries) == [])
    }
}

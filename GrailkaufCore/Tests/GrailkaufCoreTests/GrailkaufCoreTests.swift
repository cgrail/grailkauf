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

    @Test func dragBecomesAMoveAfterTheNewNeighbour() {
        let order = ["a", "b", "c", "d"]
        #expect(OrderLearning.move(in: order, from: 3, to: 0, at: friday) == Move(date: friday, key: "d", after: nil))
        #expect(OrderLearning.move(in: order, from: 0, to: 3, at: friday) == Move(date: friday, key: "a", after: "c"))
        #expect(OrderLearning.move(in: order, from: 1, to: 4, at: friday) == Move(date: friday, key: "b", after: "d"))
    }

    @Test func dragToTheSamePlaceIsNoMove() {
        let order = ["a", "b", "c"]
        #expect(OrderLearning.move(in: order, from: 1, to: 1, at: friday) == nil)
        #expect(OrderLearning.move(in: order, from: 1, to: 2, at: friday) == nil)
        #expect(OrderLearning.move(in: order, from: 9, to: 0, at: friday) == nil)
    }

    @Test func dragAfterANameThatTheOrderLacksPlacesBoth() {
        let history = trips(["a", "b"])
        let date = history[0].date + hour
        // The screen shows a, b, x, y. Drag a below y.
        let moves = OrderLearning.moves(order: ["a", "b"], new: ["x", "y"], from: 0, to: 4, at: date)
        #expect(OrderLearning.order(trips: history, moves: moves) == ["b", "x", "y", "a"])
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

    @Test func dragGivesTheRowATimeBetweenItsNewNeighbours() throws {
        let open = ["A", "B", "C"].enumerated().map { Entry(text: $1, createdAt: friday - hour + Double($0)) }
        var list = state(open)
        for (from, to, expected) in [(0, 3, ["B", "C", "A"]), (2, 0, ["C", "A", "B"]), (0, 2, ["B", "A", "C"])] {
            let change = try #require(list.reordered(from: from, to: to))
            list.rows = list.rows.map { var row = $0; if row.id == change.id { row.createdAt = change.createdAt }; return row }
            #expect(list.todo.map(\.text) == expected)
            list = state(open)
        }
        #expect(list.reordered(from: 1, to: 1) == nil)
        #expect(list.reordered(from: 1, to: 2) == nil)
    }

    @Test func repeatedFindsOpenItemsWithTheSameName() {
        let list = state([
            Entry(text: "Milch", createdAt: friday - 2), Entry(text: "Brot", createdAt: friday - 1),
            Entry(text: "Eier", createdAt: friday - hour, tickedAt: friday),
        ])
        #expect(list.repeated(by: ["2 milch", "Eier", "Salz"]).map(\.text) == ["Milch"])
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

@Suite struct WatchListTests {
    private let milk = Entry(text: "Milch", createdAt: friday - hour)
    private let cola = Entry(text: "Cola", createdAt: friday - hour)

    private func list(_ entries: [Entry], syncedAt: Date?) -> ListState {
        ListState(entries: entries, moves: [], lastSync: syncedAt, now: friday)
    }

    @Test func phoneWithLaterSyncDecidesTheItemsAndKeepsNewerWatchTicks() {
        let phone = list([milk, cola], syncedAt: friday)
        var own = list([milk], syncedAt: friday - hour)
        own.tick(milk.id, at: friday + 10)

        let shown = ListState.onWatch(phone: phone, own: own, ownVersions: own.rows)
        #expect(shown.rows.map(\.name) == ["Milch", "Cola"])
        #expect(shown.rows.map { $0.tickedAt != nil } == [true, false])
        #expect(shown.lastSync == friday)
    }

    @Test func watchWithLaterSyncDecidesTheItemsAndKeepsNewerPhoneTicks() {
        var phone = list([milk, cola], syncedAt: friday - hour)
        phone.tick(milk.id, at: friday + 10)
        let own = list([milk], syncedAt: friday)

        let shown = ListState.onWatch(phone: phone, own: own, ownVersions: [])
        #expect(shown.rows.map(\.name) == ["Milch"])
        #expect(shown.rows[0].tickedAt != nil)
    }

    @Test func watchTakesTheSectionOrderFromTheSourceWithTheLaterSync() {
        var phone = list([milk], syncedAt: friday - hour)
        phone.sections = ["produce"]
        var own = list([milk], syncedAt: friday)
        own.sections = ["dairy"]
        #expect(ListState.onWatch(phone: phone, own: own, ownVersions: []).sections == ["dairy"])
        #expect(ListState.onWatch(phone: phone, own: nil, ownVersions: []).sections == ["produce"])
    }

    @Test func emptyWatchStoreShowsThePhoneList() {
        let phone = list([milk], syncedAt: nil)
        #expect(ListState.onWatch(phone: phone, own: nil, ownVersions: []).rows.map(\.name) == ["Milch"])
        #expect(ListState.onWatch(phone: nil, own: nil, ownVersions: []).rows.isEmpty)
    }

    @Test func untickAndUnknownItemLeaveTheRestAlone() {
        var state = list([milk], syncedAt: nil)
        state.tick(milk.id, at: friday)
        state.untick(milk.id, at: friday + 1)
        state.tick(UUID(), at: friday + 2)
        #expect(state.rows.map(\.tickedAt) == [nil])
        #expect(state.rows[0].modifiedAt == friday + 1)
    }
}

@Suite struct CategoryTests {
    @Test(arguments: [("spices", Category.spices), (" Dairy.\n", .dairy), ("softdrinks", .softDrinks), ("gewürze", .other), ("", .other)])
    func modelAnswerBecomesACategory(answer: String, expected: GrailkaufCore.Category) {
        #expect(Category(answer: answer) == expected)
    }

    @Test(arguments: [("Paprika", Category.produce as GrailkaufCore.Category?), ("2 rote Paprika", .produce), ("Paprika edelsüß", nil),
                      ("Paprika Pulver", nil), ("Paprikapulver", nil), ("Milch", nil)])
    func paprikaIsAVegetable(name: String, expected: GrailkaufCore.Category?) {
        #expect(Category.fixed(name) == expected)
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

    @Test func historyListsTripsNewestFirstAndMarksWhatIsOnTheList() {
        let entries = trip(2, ["Milch", "Brot"]) + trip(1, ["2 Milch", "Eier"]) + [Entry(text: "Brot", createdAt: friday)]
        let history = Suggestions.history(entries: entries)
        #expect(history.map(\.date) == [friday - week + 60, friday - 2 * week + 60])
        #expect(history.map { $0.items.map(\.text) } == [["2 Milch", "Eier"], ["2 Milch", "Brot"]])
        #expect(history.map { $0.items.map(\.onList) } == [[false, false], [false, true]])
    }

    @Test func pastListsSuggestTheItemsInTheMostListsFirst() {
        let archived = Entry(text: "Salz", createdAt: friday - hour, archivedAt: friday - 60)
        let entries = trip(3, ["Brot", "Milch"]) + trip(2, ["Brot", "Eier"]) + trip(1, ["2 Milch", "Brot"])
            + [archived, Entry(text: "Brot", createdAt: friday)]
        #expect(Suggestions.fromPastLists(entries: entries) == ["2 Milch", "Salz", "Eier"])
        #expect(Suggestions.fromPastLists(entries: entries, limit: 1) == ["2 Milch"])
    }

    @Test func aRemovedSuggestionComesBackWithALaterList() {
        let entries = trip(2, ["Grill", "Brot"]) + trip(1, ["Brot"])
        let removed = [ItemName.key("Grill"): friday - week]
        #expect(Suggestions.fromPastLists(entries: entries, removed: removed) == ["Brot"])
        let again = entries + trip(0.5, ["Grill"])
        #expect(Suggestions.fromPastLists(entries: again, removed: removed) == ["Grill", "Brot"])
    }

    @Test func newListArchivesTheOpenItemsIntoTheHistory() {
        let archived = ["Brot", "Eier"].enumerated().map {
            Entry(text: $1, createdAt: friday - hour + Double($0), archivedAt: friday - 60)
        }
        let entries = trip(1, ["Milch", "Brot"]) + archived + [Entry(text: "Eier", createdAt: friday)]
        #expect(ListState(entries: entries, moves: [], now: friday).todo.map(\.text) == ["Eier"])
        let history = Suggestions.history(entries: entries)
        #expect(history.map(\.archived) == [true, false])
        #expect(history[0].items.map(\.text) == ["Brot", "Eier"])
        #expect(history[0].items.map(\.onList) == [false, true])
        #expect(history[1].items.map(\.onList) == [false, false])
    }

    @Test func newListEndsTheShopInProgress() {
        let ticked = Entry(text: "Milch", createdAt: friday - hour, tickedAt: friday - 60, archivedAt: friday)
        let open = Entry(text: "Brot", createdAt: friday - hour, archivedAt: friday)
        #expect(ListState(entries: [ticked, open], moves: [], now: friday).rows.isEmpty)
        let history = Suggestions.history(entries: [ticked, open])
        #expect(history.map(\.archived) == [true, false])
        #expect(history.map { $0.items.map(\.text) } == [["Brot"], ["Milch"]])
    }
}

@Suite struct InboxTests {
    @Test func keepsTextThatArrivesWhileTheAppAddsTheFirstText() throws {
        let defaults = try #require(UserDefaults(suiteName: "InboxTests"))
        defaults.removePersistentDomain(forName: "InboxTests")
        Inbox.put("Milch\nEier", in: defaults)
        Inbox.put("Brot", in: defaults)
        let taken = try #require(Inbox.text(in: defaults))
        Inbox.put("Butter", in: defaults)
        Inbox.remove(taken, from: defaults)
        #expect(taken == "Milch\nEier\nBrot")
        #expect(Inbox.text(in: defaults) == "Butter")
        Inbox.remove("Butter", from: defaults)
        #expect(Inbox.text(in: defaults) == nil)
    }
}

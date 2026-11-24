import Foundation
import Testing
@testable import GrailkaufCore

@Suite struct ArrangeTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func droppedItemLandsBeforeTheTargetOrAtTheEnd() {
        let rows = ["Milch", "Joghurt", "Butter"].map { Row(Entry(text: $0, createdAt: now)) }
        let apples = Row(Entry(text: "Äpfel", createdAt: now))
        #expect(Grid.keys(dropping: apples, before: rows[1], in: rows) == ["Milch", "Äpfel", "Joghurt", "Butter"].map(ItemName.key))
        #expect(Grid.keys(dropping: apples, before: nil, in: rows) == ["Milch", "Joghurt", "Butter", "Äpfel"].map(ItemName.key))
        // Within its own section.
        #expect(Grid.keys(dropping: rows[2], before: rows[0], in: rows) == ["Butter", "Milch", "Joghurt"].map(ItemName.key))
    }

    @Test func movedItemLandsBetweenItsNeighbours() {
        let history = [Trip(date: now, keys: ["a", "b", "c", "x"])]
        let between = OrderLearning.moves(arranging: ["a", "x", "b"], moved: "x", order: ["a", "b", "c", "x"], at: now + 1)
        #expect(OrderLearning.order(trips: history, moves: between) == ["a", "x", "b", "c"])
        let first = OrderLearning.moves(arranging: ["x", "c"], moved: "x", order: ["a", "b", "c", "x"], at: now + 1)
        #expect(OrderLearning.order(trips: history, moves: first) == ["a", "b", "x", "c"])
    }

    @Test func itemsThatTheOrderLacksJoinWhereTheyAre() {
        let history = [Trip(date: now, keys: ["a", "b"])]
        let moves = OrderLearning.moves(arranging: ["n", "a", "x"], moved: "x", order: ["a", "b"], at: now + 10)
        #expect(OrderLearning.order(trips: history, moves: moves) == ["n", "a", "x", "b"])
        let alone = OrderLearning.moves(arranging: ["n", "x"], moved: "x", order: [], at: now)
        #expect(OrderLearning.order(trips: [], moves: alone) == ["n", "x"])
    }
}

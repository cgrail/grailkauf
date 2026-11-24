import Foundation
import Testing
@testable import GrailkaufCore

@Suite struct ArrangeTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Produce: Äpfel. Dairy: Milch, Joghurt. Other: empty. Built once: each entry gets a new ID.
    private let lines: [Line]

    init() {
        let now = now
        let state = ListState(entries: [
            Entry(text: "Milch", category: "dairy", createdAt: now - 3),
            Entry(text: "Äpfel", category: "produce", createdAt: now - 2),
            Entry(text: "Joghurt", category: "dairy", createdAt: now - 1),
        ], order: [], now: now)
        lines = Grid.lines(state.todo, order: [.produce, .dairy, .other])
    }

    private func row(_ text: String) -> Row { lines.compactMap(\.row).first { $0.text == text }! }

    @Test func linesShowEverySectionWithItsItems() {
        #expect(lines.map(\.section) == [.produce, nil, .dairy, nil, nil, .other])
        #expect(Set(lines.map(\.id)).count == lines.count)
    }

    @Test func itemDropGivesItsNewSectionAndNeighbours() {
        // Äpfel between Milch and Joghurt.
        #expect(Grid.drop(lines, from: 1, to: 4)
            == .item(row("Äpfel"), section: .dairy, keys: ["Milch", "Äpfel", "Joghurt"].map(ItemName.key)))
        // Into the empty last section.
        #expect(Grid.drop(lines, from: 4, to: 6) == .item(row("Joghurt"), section: .other, keys: [ItemName.key("Joghurt")]))
    }

    @Test func itemDropAboveTheFirstHeaderGoesToTheTopOfTheFirstSection() {
        #expect(Grid.drop(lines, from: 3, to: 0)
            == .item(row("Milch"), section: .produce, keys: ["Milch", "Äpfel"].map(ItemName.key)))
    }

    @Test func headerDropGivesTheNewSectionOrder() {
        #expect(Grid.drop(lines, from: 2, to: 0) == .sections([.dairy, .produce, .other]))
        // Among its own items, the section stays where it is.
        #expect(Grid.drop(lines, from: 2, to: 4) == nil)
        #expect(Grid.drop(lines, from: 2, to: 3) == nil)
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

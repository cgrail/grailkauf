import Foundation
import Testing
@testable import GrailkaufCore

@Suite struct GridTests {
    @Test func sectionsFollowTheRouteAndUnsortedItemsGoLast() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = ListState(entries: [
            Entry(text: "Milch", category: "dairy", createdAt: now - 4),
            Entry(text: "Batterien", createdAt: now - 3),
            Entry(text: "Äpfel", category: "produce", createdAt: now - 2),
            // No category yet, but an older "Joghurt" has one.
            Entry(text: "Joghurt", category: "dairy", createdAt: now - 100, tickedAt: now - 99),
            Entry(text: "Joghurt", createdAt: now - 1),
        ], order: [], now: now)
        let sections = Grid.sections(state.todo)
        #expect(sections.map(\.category) == [.produce, .dairy, .other])
        #expect(sections[1].rows.map(\.text) == ["Milch", "Joghurt"])
    }

    @Test func shopPutsTheSectionOfTheCurrentItemFirst() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = ListState(entries: [
            Entry(text: "Milch", category: "dairy", createdAt: now - 3),
            Entry(text: "Äpfel", category: "produce", createdAt: now - 2),
            Entry(text: "Joghurt", category: "dairy", createdAt: now - 1),
        ], order: ["Milch", "Äpfel", "Joghurt"], now: now)
        let sections = Grid.shopSections(state.shop(now: now))
        #expect(sections.map(\.category) == [.dairy, .produce])
        #expect(sections[0].rows.map(\.text) == ["Milch", "Joghurt"])
    }

    @Test func smallSectionsFillTheGapsFurtherUp() {
        #expect(Grid.rows(sizes: [4, 1, 2, 2, 7, 1, 3], columns: 5) == [[0, 1], [2, 3, 5], [4], [6]])
    }

    @Test func emojiTakesTheEndOfACompoundWord() {
        #expect(ItemName.emoji("2 Äpfel") == "🍎")
        #expect(ItemName.emoji("Apfelsaft") == "🧃")
        #expect(ItemName.emoji("Zahnpasta") == "🪥")
        #expect(ItemName.emoji("Tomaten") == "🍅")
        #expect(ItemName.emoji("Batterien") == nil)
        #expect(Set(Category.allCases.map(\.emoji)).count == Category.allCases.count)
    }

    @Test func emojiSkipsANoteAfterTheItem() {
        #expect(ItemName.emoji("Zahnseide Papa") == "🦷")
        #expect(ItemName.emoji("H- Milch (5€)") == "🥛")
        #expect(ItemName.emoji("Punsch (Kinder)") == "🫖")
    }

    @Test func emojiShowsTheKindOfItem() {
        #expect(ItemName.emoji("Wiener") == "🌭")
        #expect(ItemName.emoji("Salami") == "🌭")
        #expect(ItemName.emoji("Putengeschnetzeltes") == "🦃")
        #expect(ItemName.emoji("2x Chinanudel") == "🍜")
        #expect(ItemName.emoji("Reiswaffel") == "🍘")
        #expect(ItemName.emoji("Laugenstangen") == "🥨")
        #expect(ItemName.emoji("Katzenstreu") == "🐈")
        #expect(ItemName.emoji("Eistee") == "🥤")
        #expect(ItemName.emoji("Handwärmer") == "🧤")
    }
}

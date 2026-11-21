import Testing
@testable import GrailkaufCore

@Suite struct ItemNameTests {
    @Test(arguments: [
        ("2 Milch", "milch"), ("Milch 3,5%", "milch"), ("1 l Milch", "milch"), ("Milch", "milch"),
        ("500g Hackfleisch", "hackfleisch"), ("2x Cola Zero", "cola zero"), ("eine Dose Mais", "mais"),
        ("Bio Milch", "bio milch"), ("Äpfel", "äpfel"), ("  Eier  (6er) ", "eier"), ("2", "2"),
    ])
    func key(text: String, expected: String) {
        #expect(ItemName.key(text) == expected)
    }

    @Test func displayKeepsCapitalisation() {
        #expect(ItemName.display("2 Cola Zero") == "Cola Zero")
    }

    @Test func splitsOnCommasAndLinesButNotInsideNumbers() {
        #expect(ItemName.split("Milch 3,5%, Eier,Butter\nBrot\n\n") == ["Milch 3,5%", "Eier", "Butter", "Brot"])
    }

    @Test func splitRemovesListMarks() {
        #expect(ItemName.split("✓ Punsch (Kinder)\n✓  Fanta\n◦ Eier\n- Brot\n-20% Rabatt") ==
            ["Punsch (Kinder)", "Fanta", "Eier", "Brot", "-20% Rabatt"])
    }

    @Test func spokenListSplitsOnAndAndSentences() {
        #expect(ItemName.splitSpoken("Milch 1.5% und Eier. Butter, Brot and Salt") ==
            ["Milch 1.5%", "Eier", "Butter", "Brot", "Salt"])
    }
}

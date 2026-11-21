import Foundation

/// Turns free text ("2 Milch 3,5%") into the name used for ordering ("milch") and for display ("Milch").
/// A fixed rule with no model involved, so every device derives the same name.
public enum ItemName {
    /// The text without numbers, units and quantity words, capitalisation kept.
    public static func display(_ text: String) -> String {
        let kept = text.split(whereSeparator: \.isWhitespace).filter { !isFiller(String($0)) }
        return kept.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : kept.joined(separator: " ")
    }

    /// The identity of an item for ordering and purchase rhythm.
    public static func key(_ text: String) -> String { display(text).lowercased() }

    /// "Milch, Eier\nButter" is three items. A comma between digits ("3,5%") does not split.
    /// A list mark at the start of a line goes away: Notes shares a ticked checklist line as "✓ Milch".
    public static func split(_ input: String) -> [String] {
        input.replacingOccurrences(of: #"(?<!\d),|,(?!\d)"#, with: "\n", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .map {
                $0.replacingOccurrences(of: listMark, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    /// Spoken text has no line breaks: "Milch und Eier. Butter" is three items. A dot between digits does not split.
    /// Filler words go away: "ähm, dann noch Eier" is "Eier".
    public static func splitSpoken(_ input: String) -> [String] {
        split(input.replacingOccurrences(
            of: #"(?<!\d)\.|\.(?!\d)|\s+(?:und|and)\s+"#, with: "\n", options: [.regularExpression, .caseInsensitive]))
            .map(withoutFillers)
            .filter { !$0.isEmpty }
    }

    /// "ähm" and "uh" go away anywhere. "dann", "noch", "also" or "bitte" go away at the start of an item.
    private static func withoutFillers(_ item: String) -> String {
        var words = item.split(separator: " ").filter { !hesitations.contains(bare($0)) }
        while let first = words.first, leadingFillers.contains(bare(first)) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    private static func bare(_ word: Substring) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    private static let hesitations: Set<String> = [
        "äh", "ähm", "öh", "öhm", "eh", "hm", "hmm", "mh", "uh", "uhm", "um", "umm", "erm",
    ]
    private static let leadingFillers: Set<String> = [
        "dann", "noch", "also", "außerdem", "auch", "bitte", "und", "then", "and", "plus", "please",
    ]

    /// True if `items` hold exactly the spoken words in their order. A language model may add or drop words.
    public static func isSplit(_ items: [String], of spoken: String) -> Bool {
        words(items.joined(separator: " ")) == words(spoken)
    }

    private static func words(_ text: String) -> [Substring] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }
    }

    /// "✓ ", "◦ ", "• ", "- ", "* ". A "-" or "*" counts only with a space after it, so "-20%" stays.
    private static let listMark = #"^\s*(?:[✓✔☑☐◦○•▪]|[-*](?=\s))"#

    private static func isFiller(_ token: String) -> Bool {
        let word = token.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.symbols))
        return word.isEmpty || fillers.contains(word) || word.range(of: quantity, options: .regularExpression) != nil
    }

    /// "2", "3,5", "1/2", "2x", "500g", "1,5l"
    private static let quantity = #"^\d+([.,/]\d+)?(x|g|kg|mg|l|ml|cl|dl|stk|er|lb|lbs|oz)?$"#

    private static let fillers: Set<String> = [
        // units
        "x", "g", "kg", "l", "ml", "cl", "stk", "stück", "st", "pck", "pkg", "packung", "packungen", "pack", "packs",
        "dose", "dosen", "flasche", "flaschen", "glas", "gläser", "bund", "becher", "tüte", "tüten", "beutel",
        "kasten", "kiste", "kisten", "liter", "gramm", "kilo", "pfund", "paar", "mal", "netz", "schale",
        "pcs", "pieces", "piece", "bottle", "bottles", "can", "cans", "bag", "bags", "box", "boxes", "bunch",
        "jar", "jars", "lb", "lbs", "oz", "of",
        // quantity words
        "ein", "eine", "einen", "zwei", "drei", "vier", "fünf", "sechs", "halbe", "halbes", "halber", "etwas",
        "a", "an", "one", "two", "three", "four", "five", "six", "half", "some",
    ]
}

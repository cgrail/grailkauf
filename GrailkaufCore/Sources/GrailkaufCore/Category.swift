import Foundation

/// Supermarket sections. They place an item that the learned order does not know yet, and group the grid view.
/// The cases follow the route through a typical supermarket. The screens show the sections in this order, until the user sets one.
public enum Category: String, CaseIterable, Sendable {
    case produce, tins, spices, baking, bakery, breakfast, pasta, sweets, cheese, dairy, fish, meat
    case toiletries, baby, pets, household, alcohol, softDrinks, frozen, other

    /// `saved` first, then the sections that it lacks, in the order of the cases. Unknown names are skipped.
    public static func ordered(_ saved: [String]?) -> [Category] {
        var result: [Category] = []
        for category in (saved ?? []).compactMap(Category.init(rawValue:)) + allCases where !result.contains(category) {
            result.append(category)
        }
        return result
    }

    /// Reads the answer of the language model. An answer that is not on the list is `.other`.
    public init(answer: String) {
        let word = answer.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        self = Self.allCases.first { $0.rawValue.lowercased() == word } ?? .other
    }

    /// The section of an item that the model sorts wrong, or nil. The model puts the vegetable "Paprika" in spices.
    public static func fixed(_ name: String) -> Category? {
        let words = ItemName.key(name).split(separator: " ")
        let spice: Set<Substring> = ["pulver", "powder", "gewürz", "edelsüß", "rosenscharf", "geräuchert"]
        return words.contains("paprika") && spice.isDisjoint(with: words) ? .produce : nil
    }
}

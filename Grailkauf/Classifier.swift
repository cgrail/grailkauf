import FoundationModels
import GrailkaufCore

/// Guesses the supermarket section of an item with the language model on the device. No data leaves the phone.
enum Classifier {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { true } else { false }
    }

    /// `.other` if the model is unsure. Such an item goes to the "New" group.
    /// Nil if the model failed. The app then asks again later.
    static func category(of name: String) async -> GrailkaufCore.Category? {
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(samplingMode: .greedy)
        guard let answer = try? await session.respond(to: name, options: options).content else { return nil }
        return GrailkaufCore.Category(answer: answer)
    }

    /// "Milch Sprudel" is two items, "saure Sahne" is one. Nil if the model failed or changed the words.
    static func items(in text: String) async -> [String]? {
        let session = LanguageModelSession(instructions: splitInstructions)
        let options = GenerationOptions(samplingMode: .greedy)
        let answer = try? await session.respond(to: text, generating: ItemList.self, options: options).content
        let items = (answer?.items ?? []).flatMap(ItemName.split)
        return ItemName.isSplit(items, of: text) ? items : nil
    }

    private static let splitInstructions = """
        You split one entry of a grocery shopping list, in German or English, into the products in it.
        Each product that a shop sells on its own is one item: "Milch Sprudel" is "Milch" and "Sprudel".
        Words that belong together stay one item: "saure Sahne", "zwei Liter Milch", "Zahnseide Papa".
        Keep every word as written and in its order. Do not translate, correct or add words.
        """

    private static let instructions = """
        You sort one entry of a grocery shopping list, written in German or English, into a supermarket section.
        Answer with exactly one word from this list and nothing else:
        \(GrailkaufCore.Category.allCases.map(\.rawValue).joined(separator: ", "))

        produce: fruit, vegetables, fresh herbs. bakery: bread, rolls, pastries. meat: meat, sausage, cold cuts.
        fish: fish, seafood. cheese: cheese. dairy: milk, yoghurt, butter, cream, eggs. frozen: frozen food, ice cream.
        tins: canned food, jars, ready meals. pasta: pasta, rice, grains, pulses. baking: flour, sugar, baking goods.
        spices: spices, salt, sauces, oil, vinegar, condiments. breakfast: cereal, jam, spreads, coffee, tea.
        sweets: chocolate, sweets, crisps, snacks. softDrinks: water, juice, soda. alcohol: beer, wine, spirits.
        toiletries: personal care, pharmacy. household: cleaning, paper goods, kitchen supplies.
        baby: baby food, nappies. pets: pet food and supplies. other: anything else, or if you are unsure.
        """
}

@Generable
struct ItemList {
    @Guide(description: "The items in the order written")
    var items: [String]
}

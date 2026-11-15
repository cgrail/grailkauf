import FoundationModels
import GrailkaufCore

/// Guesses the supermarket section of an item with Apple's on-device model. Nothing leaves the phone.
enum Classifier {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { true } else { false }
    }

    /// `.other` when the model is unsure; such items go to the "New" group. Nil when the model failed, so the
    /// item can be asked about again later.
    static func category(of name: String) async -> GrailkaufCore.Category? {
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(samplingMode: .greedy)
        guard let answer = try? await session.respond(to: name, options: options).content else { return nil }
        let word = answer.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        return GrailkaufCore.Category.allCases.first { $0.rawValue.lowercased() == word } ?? .other
    }

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

/// The grid view: tiles in rows of a fixed width, grouped by section.
public enum Grid {
    /// The rows by section, in the order of `Category`. Each section keeps the order of `rows`.
    /// Unsorted items go to `.other`.
    public static func sections(_ rows: [Row]) -> [(category: Category, rows: [Row])] {
        let groups = Dictionary(grouping: rows) { Category(rawValue: $0.category ?? "") ?? .other }
        return Category.allCases.compactMap { category in groups[category].map { (category, $0) } }
    }

    /// Puts each section in the first row with room for it, so small sections fill the gaps further up.
    /// A section takes one column for each item, and a full row if it has more items than the row has columns.
    /// - Returns: the indices of `sizes` for each row.
    public static func rows(sizes: [Int], columns: Int) -> [[Int]] {
        var rows: [[Int]] = []
        var used: [Int] = []
        for (index, size) in sizes.enumerated() {
            let width = min(size, columns)
            if let row = used.firstIndex(where: { $0 + width <= columns }) {
                rows[row].append(index)
                used[row] += width
            } else {
                rows.append([index])
                used.append(width)
            }
        }
        return rows
    }
}

/// The pictures of the grid view. A fixed table with no model involved.
extension ItemName {
    /// "Apfelsaft" is 🧃: a German compound word ends with what the thing is.
    /// The last word that fits wins: in "Zahnseide Papa" or "H-Milch (5€)" the note comes after the item.
    /// Nil if no word of the table fits. The grid view then shows the emoji of the section.
    public static func emoji(_ text: String) -> String? {
        key(text).split(separator: " ").reversed().lazy.compactMap { emoji(word: String($0)) }.first
    }

    private static func emoji(word: String) -> String? {
        // An ending wins over a start, and a longer word wins over a shorter one: "zahnpasta" is not "pasta".
        let byLength = emojiOf.keys.sorted { $0.count > $1.count }
        let stem = byLength.first { word.hasSuffix($0) }
            // A start of 4 letters or more takes plurals: "tomaten", "apples", "kartoffeln".
            ?? byLength.first { $0.count >= 4 && word.hasPrefix($0) }
        return stem.flatMap { emojiOf[$0] }
    }

    private static let emojiOf: [String: String] = {
        let table: [(String, [String])] = [
            ("🍎", ["apfel", "äpfel", "apple"]), ("🍐", ["birne", "pear"]), ("🍌", ["banane", "banana"]),
            ("🍊", ["orange", "mandarine", "clementine"]), ("🍋", ["zitrone", "limette", "lemon", "lime"]),
            ("🍇", ["traube", "grape"]), ("🍓", ["erdbeere", "beere", "beeren", "strawberr"]),
            ("🥑", ["avocado"]), ("🍅", ["tomate", "tomato"]), ("🥒", ["gurke", "cucumber"]),
            ("🥕", ["karotte", "möhre", "carrot"]), ("🥔", ["kartoffel", "potato"]), ("🧅", ["zwiebel", "onion"]),
            ("🧄", ["knoblauch", "garlic"]), ("🥦", ["brokkoli", "broccoli"]),
            ("🥬", ["salat", "spinat", "lettuce", "spinach"]), ("🫑", ["paprika"]),
            ("🍄", ["pilze", "champignon", "mushroom"]), ("🥛", ["milch", "milk"]), ("🥚", ["eier", "egg"]),
            ("🧀", ["käse", "cheese", "mozzarella", "parmesan"]), ("🧈", ["butter"]),
            ("🥣", ["joghurt", "jogurt", "yoghurt", "yogurt", "quark", "müsli", "cereal"]),
            ("🍞", ["brot", "bread", "toast"]), ("🥖", ["brötchen", "semmel", "baguette"]), ("🥐", ["croissant"]),
            ("🥨", ["brezel", "breze", "laugen", "pretzel"]),
            ("🍗", ["hähnchen", "huhn", "geflügel", "chicken"]), ("🦃", ["pute", "truthahn", "turkey"]), ("🥩", ["fleisch", "steak", "rinder", "beef", "meat"]),
            ("🥓", ["speck", "schinken", "bacon"]), ("🌭", ["wurst", "würstchen", "wiener", "frankfurter", "salami", "sausage"]),
            ("🐟", ["fisch", "lachs", "fish", "salmon", "tuna"]), ("🍝", ["nudel", "nudeln", "pasta", "spaghetti"]),
            ("🍜", ["chinanudel", "mienudel", "glasnudel", "reisnudel", "ramen", "noodle"]),
            ("🍚", ["reis", "rice"]), ("🍘", ["reiswaffel", "reiscracker"]), ("🌾", ["mehl", "flour"]), ("🍬", ["zucker", "sugar", "bonbon"]),
            ("🧂", ["salz", "salt"]), ("🫒", ["öl", "oil", "olive"]), ("🍫", ["schokolade", "chocolate", "nutella", "nougatcreme"]),
            ("🍪", ["keks", "kekse", "cookie"]), ("🥜", ["nuss", "nüsse", "nuts", "peanut"]), ("🍕", ["pizza"]),
            ("🍲", ["suppe", "soup"]), ("🍟", ["chips", "pommes", "crisps"]), ("🍦", ["eis", "eiscreme"]),
            ("☕", ["kaffee", "coffee"]), ("🍵", ["tee", "tea"]), ("🫖", ["punsch"]), ("💧", ["wasser", "sprudel", "water"]),
            ("🧃", ["saft", "juice"]), ("🥤", ["cola", "limo", "limonade", "fanta", "sprite", "eistee", "soda"]), ("🍺", ["bier", "beer"]),
            ("🍷", ["wein", "wine"]), ("🍯", ["honig", "honey"]), ("🫙", ["marmelade", "essig", "vinegar"]),
            ("🧻", ["papier", "paper", "taschentücher", "tissues"]),
            ("🧼", ["seife", "spülmittel", "duschgel", "soap"]), ("🪥", ["zahnpasta", "zahnbürste", "toothpaste"]),
            ("🧽", ["schwamm", "sponge"]), ("🦷", ["zahnseide", "floss"]),
            ("🧤", ["handwärmer", "handschuh", "glove"]), ("🐈", ["katze", "cat"]),
        ]
        return Dictionary(uniqueKeysWithValues: table.flatMap { emoji, stems in stems.map { ($0, emoji) } })
    }()
}

extension Category {
    /// The picture of the section, and of an item with no picture of its own.
    public var emoji: String {
        switch self {
        case .produce: "🥦"
        case .spices: "🧂"
        case .tins: "🥫"
        case .household: "🧽"
        case .toiletries: "🧴"
        case .baby: "🍼"
        case .sweets: "🍫"
        case .meat: "🥩"
        case .fish: "🐟"
        case .breakfast: "🥣"
        case .bakery: "🍞"
        case .frozen: "🧊"
        case .baking: "🌾"
        case .pasta: "🍝"
        case .cheese: "🧀"
        case .dairy: "🥛"
        case .pets: "🐾"
        case .softDrinks: "🧃"
        case .alcohol: "🍷"
        case .other: "🛒"
        }
    }
}

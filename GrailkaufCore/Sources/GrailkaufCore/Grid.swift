/// The grid view: tiles in rows of a fixed width, grouped by section.
public enum Grid {
    /// Puts sections next to each other while they fit in one row, in their order.
    /// A section takes one column for each item, and a full row if it has more items than the row has columns.
    /// - Returns: the indices of `sizes` for each row.
    public static func rows(sizes: [Int], columns: Int) -> [[Int]] {
        var rows: [[Int]] = []
        var used = columns
        for (index, size) in sizes.enumerated() {
            let width = min(size, columns)
            if used + width > columns {
                rows.append([])
                used = 0
            }
            rows[rows.count - 1].append(index)
            used += width
        }
        return rows
    }
}

/// The pictures of the grid view. A fixed table with no model involved.
extension ItemName {
    /// "Apfelsaft" is 🧃: a German compound word ends with what the thing is.
    /// Nil if no word of the table fits. The grid view then shows the emoji of the section.
    public static func emoji(_ text: String) -> String? {
        guard let word = key(text).split(separator: " ").last.map(String.init) else { return nil }
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
            ("🍗", ["hähnchen", "huhn", "geflügel", "chicken"]), ("🥩", ["fleisch", "steak", "rinder", "beef", "meat"]),
            ("🥓", ["speck", "schinken", "bacon"]), ("🌭", ["wurst", "würstchen", "sausage"]),
            ("🐟", ["fisch", "lachs", "fish", "salmon", "tuna"]), ("🍝", ["nudeln", "pasta", "spaghetti"]),
            ("🍚", ["reis", "rice"]), ("🌾", ["mehl", "flour"]), ("🍬", ["zucker", "sugar", "bonbon"]),
            ("🧂", ["salz", "salt"]), ("🫒", ["öl", "oil", "olive"]), ("🍫", ["schokolade", "chocolate"]),
            ("🍪", ["keks", "kekse", "cookie"]), ("🥜", ["nuss", "nüsse", "nuts", "peanut"]), ("🍕", ["pizza"]),
            ("🍲", ["suppe", "soup"]), ("🍟", ["chips", "pommes", "crisps"]), ("🍦", ["eis", "eiscreme"]),
            ("☕", ["kaffee", "coffee"]), ("🍵", ["tee", "tea"]), ("💧", ["wasser", "sprudel", "water"]),
            ("🧃", ["saft", "juice"]), ("🥤", ["cola", "limo", "limonade", "soda"]), ("🍺", ["bier", "beer"]),
            ("🍷", ["wein", "wine"]), ("🍯", ["honig", "honey"]), ("🫙", ["marmelade", "essig", "vinegar"]),
            ("🧻", ["papier", "paper", "taschentücher", "tissues"]),
            ("🧼", ["seife", "spülmittel", "duschgel", "soap"]), ("🪥", ["zahnpasta", "zahnbürste", "toothpaste"]),
            ("🧽", ["schwamm", "sponge"]),
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

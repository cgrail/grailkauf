import GrailkaufCore
import SwiftUI

/// The title and color of a supermarket section, on the iPhone and the Watch.
extension GrailkaufCore.Category {
    var title: LocalizedStringResource {
        switch self {
        case .produce: "Fruit & vegetables"
        case .spices: "Spices & sauces"
        case .tins: "Tins & ready meals"
        case .household: "Household"
        case .toiletries: "Care & hygiene"
        case .baby: "Baby"
        case .sweets: "Sweets & snacks"
        case .meat: "Meat & sausage"
        case .fish: "Fish"
        case .breakfast: "Breakfast, coffee & tea"
        case .bakery: "Bread & pastries"
        case .frozen: "Frozen food"
        case .baking: "Baking"
        case .pasta: "Pasta & rice"
        case .cheese: "Cheese"
        case .dairy: "Dairy & eggs"
        case .pets: "Pet food"
        case .softDrinks: "Water & juices"
        case .alcohol: "Beer, wine & spirits"
        case .other: "Other"
        }
    }

    /// Neighbouring sections of a store map often share a color, so some colors repeat.
    var color: Color {
        switch self {
        case .produce: .green
        case .spices, .tins, .baking, .pasta: .orange
        case .household: .indigo
        case .toiletries, .baby: .teal
        case .sweets, .cheese, .dairy: .yellow
        case .meat, .fish, .other: .gray
        case .breakfast, .bakery: .brown
        case .frozen: .blue
        case .pets: .purple
        case .softDrinks: .mint
        case .alcohol: .red
        }
    }
}

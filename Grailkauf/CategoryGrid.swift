import GrailkaufCore
import SwiftUI

/// The list as tiles, grouped by supermarket section and colored like the map at a store entrance.
struct CategoryGrid: View {
    let store: Store
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Five tiles a row fit about 40 items on one screen. Large text gets fewer, wider tiles.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: typeSize.isAccessibilitySize ? 3 : 5)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.state.sections, id: \.category) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text(section.category.title)
                        } icon: {
                            Text(section.category.emoji)
                        }
                        .font(.caption.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(section.rows) { row in tile(row, in: section.category) }
                        }
                    }
                    .padding(6)
                    .background(section.category.color.opacity(0.25), in: .rect(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func tile(_ row: Row, in category: GrailkaufCore.Category) -> some View {
        VStack(spacing: 0) {
            Text(ItemName.emoji(row.text) ?? category.emoji)
                .font(.title3)
                .accessibilityHidden(true)
            Text(row.text)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(.background, in: .rect(cornerRadius: 8))
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete([row.id]) }
        }
    }
}

private extension GrailkaufCore.Category {
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

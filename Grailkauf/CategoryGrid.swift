import GrailkaufCore
import SwiftUI

/// The list as tiles, grouped by supermarket section and colored like the map at a store entrance.
struct CategoryGrid: View {
    let store: Store
    @ScaledMetric private var tileWidth = 64.0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.state.sections, id: \.category) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(section.category.title)
                        } icon: {
                            Text(section.category.emoji)
                        }
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 8)], spacing: 8) {
                            ForEach(section.rows) { row in tile(row, in: section.category) }
                        }
                    }
                    .padding(12)
                    .background(section.category.color.opacity(0.25), in: .rect(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
        }
    }

    private func tile(_ row: Row, in category: GrailkaufCore.Category) -> some View {
        VStack(spacing: 4) {
            Text(ItemName.emoji(row.text) ?? category.emoji)
                .font(.title)
                .accessibilityHidden(true)
            Text(row.text)
                .font(.footnote)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(.background, in: .rect(cornerRadius: 12))
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

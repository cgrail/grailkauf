import GrailkaufCore
import SwiftUI

/// The list as tiles, grouped by supermarket section and colored like the map at a store entrance.
struct CategoryGrid: View {
    let store: Store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0
    private let gap: CGFloat = 4

    /// Five tiles a row fit about 40 items on one screen. Large text gets fewer, wider tiles.
    private var columns: Int { typeSize.isAccessibilitySize ? 3 : 5 }
    /// One tile with its padding. A section with two items is two columns and one gap wide.
    private var column: CGFloat { max(0, (width - CGFloat(columns - 1) * gap) / CGFloat(columns)) }

    var body: some View {
        let sections = store.state.sections
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Grid.rows(sizes: sections.map(\.rows.count), columns: columns), id: \.self) { row in
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(row.map { sections[$0] }, id: \.category) { section($0.category, $0.rows) }
                    }
                    // The sections of a row get the height of the tallest one.
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width - 16 } action: { width = $0 }
    }

    private func section(_ category: GrailkaufCore.Category, _ rows: [Row]) -> some View {
        let span = min(rows.count, columns)
        return VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(category.title)
            } icon: {
                Text(category.emoji)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: span), spacing: gap) {
                ForEach(rows) { row in tile(row, in: category) }
            }
        }
        .padding(6)
        .frame(width: CGFloat(span) * column + CGFloat(span - 1) * gap, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(category.color.opacity(0.25), in: .rect(cornerRadius: 12))
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
            // The language model can pick the wrong section. Later items of the same name keep the correction.
            Menu("Move to section", systemImage: "arrow.right.square") {
                ForEach(GrailkaufCore.Category.allCases.filter { $0 != category }, id: \.self) { other in
                    Button { store.setCategory(row.id, other.rawValue) } label: { Text(other.title) }
                }
            }
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

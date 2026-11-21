import GrailkaufCore
import SwiftUI

/// The list as tiles, grouped by supermarket section and colored like the map at a store entrance.
struct CategoryGrid: View {
    let store: Store
    let sections: [(category: GrailkaufCore.Category, rows: [Row])]
    /// Shop mode ticks an item with a tap. List mode has no tap.
    var onTap: ((Row) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    private let gap: CGFloat = 4

    /// Five tiles a row fit about 40 items on one screen. Large text gets fewer, wider tiles.
    private var columns: Int { typeSize.isAccessibilitySize ? 3 : 5 }

    var body: some View {
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
        }
        // Margins, not padding: the width of a section counts from the scroll view without its margins.
        .contentMargins(.horizontal, 8, for: .scrollContent)
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
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: span), spacing: gap) {
                ForEach(rows) { row in tile(row, in: category) }
            }
        }
        .padding(6)
        // A section with two items is two of the five columns wide.
        .containerRelativeFrame(.horizontal, count: columns, span: span, spacing: gap, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(category.color.opacity(0.25), in: .rect(cornerRadius: 12))
    }

    @ViewBuilder private func tile(_ row: Row, in category: GrailkaufCore.Category) -> some View {
        if let onTap {
            Button { onTap(row) } label: { picture(row, in: category) }
                .buttonStyle(.plain)
                .accessibilityAddTraits(row.tickedAt != nil ? .isSelected : [])
        } else {
            picture(row, in: category)
        }
    }

    private func picture(_ row: Row, in category: GrailkaufCore.Category) -> some View {
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
        .overlay(alignment: .topTrailing) {
            if row.tickedAt != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint).padding(2)
            }
        }
        .opacity(row.tickedAt != nil ? 0.4 : 1)
        .contentShape(.rect)
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

/// Switches between the list and the grid. One setting for list mode and shop mode.
struct GridToggle: View {
    @AppStorage("grid") private var grid = false

    var body: some View {
        Button(grid ? "Show as list" : "Show by section", systemImage: grid ? "list.bullet" : "square.grid.2x2") {
            withAnimation { grid.toggle() }
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

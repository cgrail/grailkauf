import GrailkaufCore
import SwiftUI

/// The list as tiles, grouped by supermarket section and colored like the map at a store entrance.
struct CategoryGrid: View {
    let store: Store
    let sections: [(category: GrailkaufCore.Category, rows: [Row])]
    /// Shop mode: the ticked items by section, at the bottom. A tap brings one back.
    var done: [(category: GrailkaufCore.Category, rows: [Row])] = []
    /// Shop mode ticks an item with a tap. In list mode, a tap opens the editor.
    var onTap: ((Row) -> Void)?
    @State private var editing: Row?
    @State private var showsDone = false
    /// The width of the scroll view, measured. `containerRelativeFrame` sometimes made a section a few points wide.
    @State private var width: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    private let gap: CGFloat = 4
    private let margin: CGFloat = 8

    /// Five tiles a row fit about 40 items on one screen. Large text gets fewer, wider tiles.
    private var columns: Int { typeSize.isAccessibilitySize ? 3 : 5 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                packed(sections)
                if !done.isEmpty {
                    Divider().padding(.vertical, 6)
                    DisclosureGroup(isExpanded: $showsDone) {
                        VStack(alignment: .leading, spacing: 6) { packed(done, faded: true) }
                    } label: {
                        Text("Done (\(done.reduce(0) { $0 + $1.rows.count }))")
                            .font(.caption.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sheet(item: $editing) { row in
            let section = sections.first { $0.rows.contains { $0.id == row.id } }?.category ?? .other
            TileEditor(row: row, section: section, store: store)
        }
    }

    private func packed(_ sections: [(category: GrailkaufCore.Category, rows: [Row])], faded: Bool = false) -> some View {
        ForEach(Grid.rows(sizes: sections.map(\.rows.count), columns: columns), id: \.self) { row in
            let widths = Grid.widths(spans: row.map { min(sections[$0].rows.count, columns) }, width: width - 2 * margin, gap: gap)
            HStack(alignment: .top, spacing: gap) {
                ForEach(Array(row.enumerated()), id: \.element) { place, index in
                    section(sections[index].category, sections[index].rows, width: widths[place], faded: faded)
                }
            }
            // The sections of a row get the height of the tallest one.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A faded section holds only ticked tiles. Its color and title fade as its tiles do.
    private func section(_ category: GrailkaufCore.Category, _ rows: [Row], width: CGFloat, faded: Bool = false) -> some View {
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
            .opacity(faded ? 0.4 : 1)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: span), spacing: gap) {
                ForEach(rows) { row in tile(row, in: category) }
            }
        }
        .padding(6)
        // The row fills the screen. A section with two items gets two shares of it.
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(category.color.opacity(faded ? 0.1 : 0.25), in: .rect(cornerRadius: 12))
    }

    @ViewBuilder private func tile(_ row: Row, in category: GrailkaufCore.Category) -> some View {
        Button { if let onTap { onTap(row) } else { editing = row } } label: { picture(row, in: category) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(row.tickedAt != nil ? .isSelected : [])
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

/// List mode: a tap on a tile opens this. Change the name, move the item to another section, or delete it.
private struct TileEditor: View {
    let row: Row
    let store: Store
    private let section: GrailkaufCore.Category
    @State private var text: String
    @State private var category: GrailkaufCore.Category
    @Environment(\.dismiss) private var dismiss

    init(row: Row, section: GrailkaufCore.Category, store: Store) {
        self.row = row
        self.section = section
        self.store = store
        _text = State(initialValue: row.text)
        _category = State(initialValue: section)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item", text: $text).onSubmit(save)
                // The language model can pick the wrong section. Later items of the same name keep the correction.
                Picker("Section", selection: $category) {
                    ForEach(GrailkaufCore.Category.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.delete([row.id])
                    dismiss()
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark", action: save) }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        // The text first: a new name takes the section of earlier items of that name, and the choice here must win.
        store.edit(row, to: text)
        if category != section { store.setCategory(row.id, category.rawValue) }
        dismiss()
    }
}

/// Shop mode: switches between the list and the grid.
struct GridToggle: View {
    @AppStorage("grid") private var grid = false

    var body: some View {
        Button(grid ? "Show as list" : "Show by section", systemImage: grid ? "list.bullet" : "square.grid.2x2") {
            withAnimation { grid.toggle() }
        }
    }
}

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
    /// The Mac moves a tile with a drag: the item lands in the section, before the given tile or at the end.
    /// Nil: no drag. On the iPhone, touch and hold opens the menu of the tile.
    var onDrop: ((_ id: UUID, _ section: GrailkaufCore.Category, _ before: Row?) -> Void)?
    @State private var editing: Row?
    @State private var showsDone = false
    /// The tile or section under a dragged tile, by `id` or section name.
    @State private var target: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    private let gap: CGFloat = 4

    /// Five tiles a row fit about 40 items on one screen. Large text gets fewer, wider tiles. A Mac window is wider.
    private var columns: Int {
        #if os(macOS)
        8
        #else
        typeSize.isAccessibilitySize ? 3 : 5
        #endif
    }

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
        // In list mode the scroll view otherwise takes the width of its content, and the sections size to the scroll view.
        .frame(maxWidth: .infinity)
        // Margins, not padding: the width of a section counts from the scroll view without its margins.
        .contentMargins(.horizontal, 8, for: .scrollContent)
        .sheet(item: $editing) { row in
            let section = sections.first { $0.rows.contains { $0.id == row.id } }?.category ?? .other
            TileEditor(row: row, section: section, store: store)
        }
    }

    private func packed(_ sections: [(category: GrailkaufCore.Category, rows: [Row])], faded: Bool = false) -> some View {
        ForEach(Grid.rows(sizes: sections.map(\.rows.count), columns: columns), id: \.self) { row in
            let used = row.reduce(0) { $0 + min(sections[$1].rows.count, columns) }
            HStack(alignment: .top, spacing: gap) {
                ForEach(row.map { sections[$0] }, id: \.category) { section($0.category, $0.rows, of: used, faded: faded) }
            }
            // The sections of a row get the height of the tallest one.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A faded section holds only ticked tiles. Its color and title fade as its tiles do.
    /// `used` is the number of columns that the sections of the row take. The row fills the full width.
    private func section(_ category: GrailkaufCore.Category, _ rows: [Row], of used: Int, faded: Bool = false) -> some View {
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
        // A section with two items next to one with three is two fifths of the row wide.
        .containerRelativeFrame(.horizontal, count: used, span: span, spacing: gap, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(category.color.opacity(faded ? 0.1 : 0.25), in: .rect(cornerRadius: 12))
        .overlay {
            if target == category.rawValue { RoundedRectangle(cornerRadius: 12).stroke(.tint, lineWidth: 2) }
        }
        .droppable(onDrop != nil && !faded, key: category.rawValue, target: $target) { drop($0, in: category, before: nil) }
    }

    /// False if the item is dropped on itself.
    private func drop(_ id: String, in section: GrailkaufCore.Category, before row: Row?) -> Bool {
        guard let id = UUID(uuidString: id), id != row?.id else { return false }
        onDrop?(id, section, row)
        return true
    }

    @ViewBuilder private func tile(_ row: Row, in category: GrailkaufCore.Category) -> some View {
        let key = row.id.uuidString
        Button { if let onTap { onTap(row) } else { editing = row } } label: { picture(row, in: category) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(row.tickedAt != nil ? .isSelected : [])
            // A line before the tile shows where the dragged item lands.
            .overlay(alignment: .leading) {
                if target == key { Capsule().fill(.tint).frame(width: 3).offset(x: -(gap + 3) / 2) }
            }
            .droppable(onDrop != nil && row.tickedAt == nil, key: key, dragged: key, target: $target) { drop($0, in: category, before: row) }
    }

    private func picture(_ row: Row, in category: GrailkaufCore.Category) -> some View {
        VStack(spacing: 0) {
            Text(ItemName.emoji(row.text) ?? category.emoji)
                .font(.title3)
                .accessibilityHidden(true)
            Text(row.text)
                .font(.caption2)
                .lineLimit(1)
            RowDetails(row: row)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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

extension View {
    /// Drag and drop of tiles, if `enabled`. A tile drags its item ID as `dragged`.
    /// `target` names the view under the pointer by `key`. `perform` gets the dropped item ID.
    @ViewBuilder func droppable(
        _ enabled: Bool, key: String, dragged: String? = nil, target: Binding<String?>,
        perform: @escaping (String) -> Bool
    ) -> some View {
        if enabled {
            let drop = dropDestination(for: String.self) { ids, _ in
                ids.first.map(perform) ?? false
            } isTargeted: { over in
                if over { target.wrappedValue = key } else if target.wrappedValue == key { target.wrappedValue = nil }
            }
            if let dragged { drop.draggable(dragged) } else { drop }
        } else {
            self
        }
    }
}

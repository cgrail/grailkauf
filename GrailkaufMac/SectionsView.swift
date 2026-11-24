import GrailkaufCore
import SwiftUI

/// The items by supermarket section, in the learned order. Drag an item to a new place or into another section.
/// Drag a section header to move the section. Every change applies at once, for everyone who shares the list.
struct MacSectionsView: View {
    let store: Store

    var body: some View {
        let lines = Grid.lines(store.state.shop(now: .now), order: store.state.sectionOrder)
        List {
            ForEach(lines) { line in
                switch line {
                case .section(let section): section.label.font(.headline).padding(.top, 8)
                case .item(let row): item(row)
                }
            }
            .onMove { from, to in
                if let source = from.first, let drop = Grid.drop(lines, from: source, to: to) { apply(drop) }
            }
        }
        .toolbar {
            // Back to the route of a typical supermarket.
            if store.state.sections != nil {
                Button("Reset") { store.setSections(nil) }
            }
        }
        .navigationTitle("Sections")
    }

    private func item(_ row: Row) -> some View {
        HStack {
            Text(row.text)
            Spacer()
            RowDetails(row: row)
        }
        .padding(.leading, 28)
        .contextMenu {
            // Also the way to change the section without a drag.
            Menu("Move to section", systemImage: "arrow.right.square") {
                ForEach(GrailkaufCore.Category.allCases, id: \.self) { section in
                    Button { store.setCategory(row.id, section.rawValue) } label: { Text(section.title) }
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete([row.id]) }
        }
    }

    private func apply(_ drop: Drop) {
        switch drop {
        case .sections(let order):
            store.setSections(order)
        case .item(let row, let section, let keys):
            // An item with no section yet shows in "Other". A drag within "Other" leaves it for the language model.
            if (GrailkaufCore.Category(rawValue: row.category ?? "") ?? .other) != section {
                store.setCategory(row.id, section.rawValue)
            }
            for move in OrderLearning.moves(arranging: keys, moved: ItemName.key(row.text), order: store.order, at: .now) {
                store.record(move)
            }
        }
    }
}

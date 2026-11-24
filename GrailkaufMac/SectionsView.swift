import GrailkaufCore
import SwiftUI

/// The items as tiles by supermarket section, as on the iPhone. Drag a tile onto another tile to put it there,
/// also in another section, or onto a section to put it at the end. Click a tile to change it.
struct MacSectionsView: View {
    let store: Store

    var body: some View {
        // The learned order, as in shop mode: the grid is a map of the store, not a history of the list.
        let sections = Grid.sections(store.state.shop(now: .now), order: store.state.sectionOrder)
        CategoryGrid(store: store, sections: sections, onDrop: { id, section, before in
            guard let row = sections.flatMap(\.rows).first(where: { $0.id == id }) else { return }
            // An item with no section yet shows in "Other". A drag within "Other" leaves it for the language model.
            if (GrailkaufCore.Category(rawValue: row.category ?? "") ?? .other) != section {
                store.setCategory(row.id, section.rawValue)
            }
            let keys = Grid.keys(dropping: row, before: before, in: sections.first { $0.category == section }?.rows ?? [])
            for move in OrderLearning.moves(arranging: keys, moved: ItemName.key(row.text), order: store.order, at: .now) {
                store.record(move)
            }
        })
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView(
                    "The list is empty", systemImage: "cart", description: Text("Add items to the list. Then drag them into the order of your shop."))
            }
        }
        .navigationTitle("Sections")
    }
}

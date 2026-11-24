import GrailkaufCore
import SwiftUI

/// The learned order, numbered, then the items on the list that it lacks.
/// Dragging an item places it at once, also before the first trip; later trips keep teaching it.
struct OrderView: View {
    let store: Store

    var body: some View {
        let order = store.order
        let entries = store.entries.sorted { $0.createdAt < $1.createdAt }
        let names = Dictionary(entries.map { ($0.key, ItemName.display($0.text)) }, uniquingKeysWith: { _, latest in latest })
        let known = Set(order)
        var new: [String] = []
        for entry in entries where entry.isOpen && !known.contains(entry.key) && !new.contains(entry.key) {
            new.append(entry.key)
        }
        return List {
            Section {
                ForEach(Array((order + new).enumerated()), id: \.element) { index, key in
                    HStack {
                        DragHandle()
                        if index < order.count {
                            Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "sparkles").foregroundStyle(.secondary).accessibilityLabel("New")
                        }
                        Text(names[key] ?? key)
                    }
                }
                .onMove { from, to in
                    guard let source = from.first else { return }
                    for move in OrderLearning.moves(order: order, new: new, from: source, to: to, at: .now) {
                        store.record(move)
                    }
                }
            } footer: {
                Text("Drag an item to where you pick it up. The order keeps learning from your shopping.")
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .overlay {
            if order.isEmpty && new.isEmpty {
                ContentUnavailableView(
                    "Order", systemImage: "list.number",
                    description: Text("Add items to the list. Then drag them into the order of your shop."))
            }
        }
        .navigationTitle("Order")
    }
}

/// The sections in the order of the user's shop. A drag applies at once, for everyone who shares the list.
struct SectionOrderView: View {
    let store: Store

    var body: some View {
        let order = store.state.sectionOrder
        List {
            Section {
                ForEach(Array(order.enumerated()), id: \.element) { index, section in
                    HStack {
                        DragHandle()
                        Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                        Label { Text(section.title) } icon: { Text(section.emoji) }
                    }
                }
                .onMove { from, to in
                    var moved = order
                    moved.move(fromOffsets: from, toOffset: to)
                    store.setSections(moved)
                }
            } footer: {
                Text("Drag the sections into the order of your shop. Shop mode then goes through them in this order.")
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .toolbar {
            // Back to the route of a typical supermarket, and to the learned order alone in shop mode.
            if store.state.sections != nil {
                Button("Reset") { store.setSections(nil) }
            }
        }
        .navigationTitle("Sections")
    }
}

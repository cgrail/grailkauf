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

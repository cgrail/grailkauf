import GrailkaufCore
import SwiftUI

/// The Mac writes the list and puts it in order. iCloud brings it to the iPhone and the Watch, where you shop.
@main
struct GrailkaufMacApp: App {
    private let store = Store(ownsList: true)

    var body: some Scene {
        Window(Text(verbatim: "Grailkauf"), id: "main") { MacRootView(store: store) }
    }
}

private enum Page: Hashable {
    case list, sections, order, sectionOrder
}

struct MacRootView: View {
    let store: Store
    @State private var page: Page? = .list
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Label("List", systemImage: "list.bullet").tag(Page.list)
                Label("Sections", systemImage: "square.grid.2x2").tag(Page.sections)
                Label("Order", systemImage: "list.number").tag(Page.order)
                Label("Section order", systemImage: "arrow.up.arrow.down").tag(Page.sectionOrder)
            }
            .safeAreaInset(edge: .bottom) {
                SyncLabel(lastSync: store.lastSync).font(.footnote).foregroundStyle(.secondary).padding()
            }
        } detail: {
            switch page {
            case .order: OrderView(store: store)
            case .sections: MacSectionsView(store: store)
            case .sectionOrder: SectionOrderView(store: store)
            case .list, nil: MacListView(store: store)
            }
        }
        // The grid fits eight tiles in a row.
        .frame(minWidth: 760, minHeight: 480)
        .task { store.refresh() }
        // Time alone changes the list: a trip ends four hours after its last tick.
        .onChange(of: scenePhase) { if scenePhase == .active { store.refresh() } }
        .alert("Something went wrong", isPresented: .constant(store.problem != nil)) {
            Button("OK") { store.problem = nil }
        } message: {
            Text(store.problem ?? "")
        }
    }
}

/// The list as on the iPhone: type an item and press Enter. Click a text to change it, drag an item to move it.
struct MacListView: View {
    let store: Store
    @State private var draft = ""

    var body: some View {
        let items = store.state.todo
        List {
            ForEach(items) { ItemRow(row: $0, store: store) }
                .onMove { from, to in
                    if let source = from.first, let change = store.state.reordered(from: source, to: to) {
                        store.move(change.id, toCreatedAt: change.createdAt)
                    }
                }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "The list is empty", systemImage: "cart", description: Text("Type below to add the first item."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            // A vertical field keeps the lines of pasted text. Each line becomes one item.
            TextField("Add item", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
                .onChange(of: draft) { if draft.contains(where: \.isNewline) { add() } }
                .padding()
                .background(.bar)
        }
        .navigationTitle("List")
    }

    private func add() {
        store.add(draft)
        draft = ""
    }
}

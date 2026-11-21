import GrailkaufCore
import SwiftUI

/// Walking the store: the list in learned order, one tap per item.
struct ShopModeView: View {
    @Environment(AppModel.self) private var model
    /// The rows that were ticked a moment ago. They stay in place, faded, so the user can undo a wrong tap.
    @State private var lingering: Set<UUID> = []
    @AppStorage("grid") private var grid = false

    private var store: Store { model.store }

    var body: some View {
        let now = Date.now
        let open = store.state.shop(now: now, lingering: lingering)
        let done = store.state.done(now: now).filter { !lingering.contains($0.id) }
        let left = open.count { $0.tickedAt == nil }
        let total = open.count + done.count
        Group {
            if grid {
                // Each section keeps the learned order. A ticked tile fades out as a ticked row does.
                CategoryGrid(store: store, sections: Grid.sections(open), done: Grid.sections(done), onTap: toggle)
            } else {
                list(open: open, done: done, left: left, total: total)
            }
        }
        .animation(.default, value: open.map(\.id))
        .overlay {
            if total == 0 { ContentUnavailableView("The list is empty", systemImage: "cart") }
        }
        .toolbar {
            if total > 0 {
                ToolbarItem(placement: .topBarTrailing) { GridToggle() }
            }
        }
    }

    private func list(open: [Row], done: [Row], left: Int, total: Int) -> some View {
        List {
            Section {
                ProgressView(value: Double(total - left), total: Double(max(total, 1))) {
                    Text("\(total - left) / \(total)").monospacedDigit()
                } currentValueLabel: {
                    SyncLabel(lastSync: store.lastSync)
                }
            }
            if open.contains(where: \.isNew) {
                Section("New") { rows(open.filter(\.isNew)) }
            }
            Section { rows(open.filter { !$0.isNew }) }
            if !done.isEmpty {
                Section {
                    DisclosureGroup("Done (\(done.count))") { rows(done) }
                }
            }
        }
    }

    private func rows(_ rows: [Row]) -> some View {
        ForEach(rows) { row in
            let ticked = row.tickedAt != nil
            Button {
                toggle(row)
            } label: {
                HStack {
                    Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ticked ? Color.accentColor : .secondary)
                    Text(row.text)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .opacity(ticked ? 0.4 : 1)
            .accessibilityAddTraits(ticked ? .isSelected : [])
        }
    }

    private func toggle(_ row: Row) {
        guard row.tickedAt == nil else {
            lingering.remove(row.id)
            store.setTicked(row.id, false)
            return
        }
        lingering.insert(row.id)
        store.setTicked(row.id, true)
        Task {
            try? await Task.sleep(for: .seconds(2))
            lingering.remove(row.id)
        }
    }
}

import GrailkaufCore
import SwiftUI

/// Walking the store: the list in learned order, one tap per item.
struct ShopModeView: View {
    @Environment(AppModel.self) private var model
    /// The rows that were ticked a moment ago. They stay in place, faded, so the user can undo a wrong tap.
    @State private var lingering: Set<UUID> = []

    private var store: Store { model.store }

    var body: some View {
        let now = Date.now
        let open = store.state.shop(now: now, lingering: lingering)
        let done = store.state.done(now: now).filter { !lingering.contains($0.id) }
        let left = open.count { $0.tickedAt == nil }
        let total = open.count + done.count
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
        .animation(.default, value: open.map(\.id))
        .overlay {
            if total == 0 { ContentUnavailableView("The list is empty", systemImage: "cart") }
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
                    if row.guessed && !ticked {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Placed by guess")
                    }
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

import GrailkaufCore
import SwiftUI

/// Walking the store: the list in learned order, one tap per item.
struct ShopModeView: View {
    @Environment(AppModel.self) private var model
    /// The rows that were ticked a moment ago. They stay in place, faded, so the user can undo a wrong tap.
    @State private var lingering: Set<UUID> = []
    @AppStorage("grid") private var grid = false

    private var store: Store { model.store }
    private var order: [GrailkaufCore.Category] { store.state.sectionOrder }

    var body: some View {
        let now = Date.now
        let open = store.state.shop(now: now, lingering: lingering)
        let done = store.state.done(now: now).filter { !lingering.contains($0.id) }
        let left = open.count { $0.tickedAt == nil }
        let total = open.count + done.count
        Group {
            if grid {
                // Each section keeps the learned order. A ticked tile fades out as a ticked row does.
                CategoryGrid(store: store, sections: Grid.sections(open, order: order), done: Grid.sections(done, order: order), onTap: toggle)
            } else {
                list(open: open, done: done, left: left, total: total)
            }
        }
        // Above the list, not over it, so the done items stay readable and a wrong tick can be undone.
        .safeAreaInset(edge: .top) {
            if total > 0, open.isEmpty { AllDone().transition(.scale.combined(with: .opacity)) }
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
            // By section, as on the Watch.
            ForEach(Grid.shopSections(open.filter { !$0.isNew }, order: order), id: \.category) { section in
                Section {
                    rows(section.rows)
                } header: {
                    section.category.label
                }
            }
            if !done.isEmpty {
                Section {
                    DisclosureGroup("Done (\(done.count))") {
                        ForEach(Grid.sections(done, order: order), id: \.category) { section in
                            section.category.label.font(.footnote).foregroundStyle(.secondary)
                            rows(section.rows)
                        }
                    }
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
                    RowDetails(row: row)
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

/// A big party popper when every item is ticked.
struct AllDone: View {
    var body: some View {
        VStack {
            Text("🎉").font(.system(size: 80)).accessibilityHidden(true)
            Text("All done.").font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
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

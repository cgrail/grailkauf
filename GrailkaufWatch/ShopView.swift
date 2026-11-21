import GrailkaufCore
import SwiftUI

struct ShopView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var unreachable = false

    var body: some View {
        let now = Date.now
        let open = model.state.shop(now: now)
        let done = model.state.done(now: now)
        let total = done.count + open.count
        NavigationStack {
            List {
                if let current = open.first {
                    Section {
                        Button {
                            model.tick(current.id)
                        } label: {
                            VStack(alignment: .leading) {
                                if current.isNew {
                                    Text("New").font(.caption2).foregroundStyle(.secondary)
                                }
                                item(current).font(.title3.bold())
                            }
                        }
                        .handGestureShortcut(.primaryAction)
                        .swipeActions { later(current) }
                        if open.count > 1 {
                            Text(open.dropFirst().prefix(3).map(\.name).joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Grid.sections(Array(open.dropFirst())), id: \.category) { section in
                        Section {
                            ForEach(section.rows) { row in
                                Button { model.tick(row.id) } label: { item(row) }
                                    .swipeActions { later(row) }
                            }
                        } header: {
                            Label { Text(section.category.title) } icon: { Text(section.category.emoji) }
                        }
                    }
                } else if !model.hasData {
                    Text("Open Grailkauf on your iPhone to load the list.")
                } else {
                    Text(done.isEmpty ? "The list is empty." : "All done.")
                }
                if !done.isEmpty {
                    Section("Done") {
                        ForEach(done) { row in
                            Button {
                                model.untick(row.id)
                            } label: {
                                item(row, ticked: true).strikethrough().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button("Refresh", systemImage: "arrow.clockwise") { pull() }
                } footer: {
                    VStack(alignment: .leading) {
                        SyncLabel(lastSync: model.state.lastSync)
                        if unreachable { Text("iPhone not reachable.") }
                    }
                }
            }
            .toolbar {
                if total > 0 {
                    // Small, in the corner across from the time, so the current item is on the first screen.
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 4) {
                            ProgressView(value: Double(done.count), total: Double(total))
                                .progressViewStyle(.circular)
                                .frame(width: 16, height: 16)
                            Text("\(done.count)/\(total)").font(.footnote).monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("\(done.count)/\(total)"))
                    }
                }
            }
        }
        // The app gets the list from the phone when it opens. The list is then current before the first tick.
        .onChange(of: scenePhase, initial: true) { if scenePhase == .active { pull() } }
    }

    /// An empty box for an open item, a tick for a done one, then the picture of the item or of its section.
    private func item(_ row: Row, ticked: Bool = false) -> some View {
        let section = GrailkaufCore.Category(rawValue: row.category ?? "") ?? .other
        return HStack(spacing: 6) {
            Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ticked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(ItemName.emoji(row.text) ?? section.emoji)
            Text(row.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.text)
        .accessibilityAddTraits(ticked ? .isSelected : [])
    }

    private func later(_ row: Row) -> some View {
        Button("Later", systemImage: "arrow.uturn.down") { model.later(row.id) }
    }

    private func pull() {
        Task { unreachable = !(await model.refresh()) }
    }
}

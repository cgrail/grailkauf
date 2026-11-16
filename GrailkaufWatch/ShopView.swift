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
        List {
            if let current = open.first {
                Section {
                    ProgressView(value: Double(done.count), total: Double(done.count + open.count)) {
                        Text("\(done.count) / \(done.count + open.count)").monospacedDigit()
                    }
                    Button {
                        model.tick(current.id)
                    } label: {
                        VStack(alignment: .leading) {
                            if current.isNew {
                                Text("New").font(.caption2).foregroundStyle(.secondary)
                            } else if current.guessed {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Placed by guess")
                            }
                            Text(current.text).font(.title3.bold())
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
                if open.count > 1 {
                    Section("List") {
                        ForEach(open.dropFirst()) { row in
                            Button(row.text) { model.tick(row.id) }
                                .swipeActions { later(row) }
                        }
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
                            Text(row.text).strikethrough().foregroundStyle(.secondary)
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
        // The app gets the list from the phone when it opens. The list is then current before the first tick.
        .onChange(of: scenePhase, initial: true) { if scenePhase == .active { pull() } }
    }

    private func later(_ row: Row) -> some View {
        Button("Later", systemImage: "arrow.uturn.down") { model.later(row.id) }
    }

    private func pull() {
        Task { unreachable = !(await model.refresh()) }
    }
}

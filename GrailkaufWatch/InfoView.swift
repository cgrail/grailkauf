import SwiftUI

/// What the app is, which build runs, and "Refresh" for the rare case that the automatic sync misses a change.
struct InfoView: View {
    @Environment(WatchModel.self) private var model
    @State private var unreachable = false

    var body: some View {
        List {
            Section {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { unreachable = !(await model.refresh()) }
                }
            } footer: {
                VStack(alignment: .leading) {
                    SyncLabel(lastSync: model.state.lastSync)
                    if unreachable { Text("iPhone not reachable.") }
                }
            }
            Section {
                Text("A shared shopping list that learns the order of your shop.")
                LabeledContent("Version", value: "\(info("CFBundleShortVersionString")) (\(info("CFBundleVersion")))")
                // GitCommit comes from the "Git commit" build phase of the Watch target.
                LabeledContent("Commit", value: info("GitCommit"))
            }
        }
        .navigationTitle("Info")
    }

    private func info(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "–"
    }
}

import CloudKit
import GrailkaufCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var sharing: Sharing?

    private struct Sharing: Identifiable {
        let id = UUID()
        let share: CKShare
        let container: CKContainer
    }

    var body: some View {
        List {
            Section {
                NavigationLink("Order") { OrderView() }
            }
            Section {
                Button("Invite", systemImage: "person.badge.plus") {
                    Task {
                        do {
                            let (share, container) = try await model.store.share()
                            sharing = Sharing(share: share, container: container)
                        } catch {
                            model.store.problem = error.localizedDescription
                        }
                    }
                }
            } header: {
                Text("Sharing")
            } footer: {
                // No iCloud account on this device: everything still works, but only here.
                if FileManager.default.ubiquityIdentityToken == nil {
                    Text("You are not signed in to iCloud. The list stays on this device.")
                }
            }
            Section {
                LabeledContent("Last updated") {
                    if let lastSync = model.store.lastSync {
                        Text(lastSync, format: .dateTime.day().month().hour().minute())
                    } else {
                        Text("Never")
                    }
                }
            }
            Section("Privacy") {
                Text("Grailkauf collects no data. Your iCloud stores the list. Only the people you invite can see it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                // App Review requires the policy inside the app too (guideline 5.1.1).
                SwiftUI.Link("Privacy Policy", destination: URL(string: "https://grails.de/grailkauf/privacy-policy.html")!)
            }
        }
        .navigationTitle("Settings")
        .sheet(item: $sharing) { CloudSharingView(share: $0.share, container: $0.container) }
    }
}

/// The learned order, numbered, then the items on the list that it lacks.
/// Dragging an item places it at once, also before the first trip; later trips keep teaching it.
struct OrderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let order = model.store.order
        let entries = model.store.entries.sorted { $0.createdAt < $1.createdAt }
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
                        model.store.record(move)
                    }
                }
            } footer: {
                Text("Drag an item to where you pick it up. The order keeps learning from your shopping.")
            }
        }
        .environment(\.editMode, .constant(.active))
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

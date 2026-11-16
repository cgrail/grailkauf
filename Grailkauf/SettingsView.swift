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
            }
        }
        .navigationTitle("Settings")
        .sheet(item: $sharing) { CloudSharingView(share: $0.share, container: $0.container) }
    }
}

/// The learned order, numbered. Dragging an item corrects it at once; later trips keep teaching it.
struct OrderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let order = model.store.order
        let names = Dictionary(
            model.store.entries.sorted { $0.createdAt < $1.createdAt }.map { ($0.key, ItemName.display($0.text)) },
            uniquingKeysWith: { _, latest in latest })
        List {
            Section {
                ForEach(Array(order.enumerated()), id: \.element) { index, key in
                    HStack {
                        Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                        Text(names[key] ?? key)
                    }
                }
                .onMove { from, to in
                    guard let source = from.first,
                          let move = OrderLearning.move(in: order, from: source, to: to, at: .now)
                    else { return }
                    model.store.record(move)
                }
            } footer: {
                Text("Drag an item to where you pick it up. The order keeps learning from your shopping.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .overlay {
            if order.isEmpty {
                ContentUnavailableView(
                    "Order", systemImage: "list.number",
                    description: Text("The order appears after your first shopping trip."))
            }
        }
        .navigationTitle("Order")
    }
}

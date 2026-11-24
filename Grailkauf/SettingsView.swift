import CloudKit
import GrailkaufCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var sharing: Sharing?
    @AppStorage("details") private var details = false
    /// The schema upload: nil before it, false while it runs, true when it is done.
    @State private var schemaUploaded: Bool?

    private struct Sharing: Identifiable {
        let id = UUID()
        let share: CKShare
        let container: CKContainer
    }

    var body: some View {
        List {
            Section {
                NavigationLink("Order") { OrderView(store: model.store) }
                NavigationLink("Sections") { SectionOrderView(store: model.store) }
                Toggle("Show details", isOn: $details)
            } footer: {
                Text("Details show the position of each item in the order and the picture of its section.")
            }
            Section {
                NavigationLink("Export") { ExportView() }
            } footer: {
                Text("Send the list to Notes or another app, without the sections that you switch off.")
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
            #if DEBUG
            // Only a Debug build talks to the Development environment of iCloud.
            Section {
                Button("Upload iCloud schema", systemImage: "icloud.and.arrow.up") {
                    schemaUploaded = false
                    Task {
                        do {
                            try await model.store.uploadSchema()
                            schemaUploaded = true
                        } catch {
                            schemaUploaded = nil
                            model.store.problem = error.localizedDescription
                        }
                    }
                }
                .disabled(schemaUploaded == false)
            } footer: {
                if schemaUploaded == true {
                    Text("Uploaded. Deploy the schema to Production in the CloudKit Console.")
                } else {
                    Text("Debug builds only. Sends every entity and field to the Development schema in iCloud.")
                }
            }
            #endif
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

/// The sections in the order of the user's shop. A drag applies at once, for everyone who shares the list.
struct SectionOrderView: View {
    let store: Store

    var body: some View {
        let order = store.state.sectionOrder
        List {
            Section {
                ForEach(order, id: \.self) { section in
                    Label { Text(section.title) } icon: { Text(section.emoji) }
                }
                .onMove { from, to in
                    var moved = order
                    moved.move(fromOffsets: from, toOffset: to)
                    store.setSections(moved)
                }
            } footer: {
                Text("Drag the sections into the order of your shop. Shop mode then goes through them in this order.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .toolbar {
            // Back to the route of a typical supermarket, and to the learned order alone in shop mode.
            if store.state.sections != nil {
                Button("Reset") { store.setSections(nil) }
            }
        }
        .navigationTitle("Sections")
    }
}

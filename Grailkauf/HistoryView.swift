import GrailkaufCore
import SwiftUI

/// Past trips, newest first. Items that are not on the list now have a button to add them again.
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let trips = Suggestions.history(entries: model.store.entries)
        List(trips, id: \.date) { trip in
            Section {
                ForEach(trip.items.filter { !$0.onList }, id: \.text) { item in
                    HStack {
                        Text(item.text)
                        Spacer()
                        Button("Add", systemImage: "plus.circle") { model.store.add(item.text) }
                            .labelStyle(.iconOnly)
                    }
                }
                let listed = trip.items.filter(\.onList)
                if !listed.isEmpty {
                    DisclosureGroup("\(listed.count) items already on the list") {
                        ForEach(listed, id: \.text) { Text($0.text).foregroundStyle(.secondary) }
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("\(trip.date, format: .dateTime.day().month(.wide)) (\(trip.date, format: .relative(presentation: .named)))")
            }
        }
        .overlay {
            if trips.isEmpty {
                ContentUnavailableView(
                    "History", systemImage: "clock",
                    description: Text("Your shopping trips appear here after your first shop."))
            }
        }
        .navigationTitle("History")
    }
}

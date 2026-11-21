import GrailkaufCore
import SwiftUI

/// One past trip. Items that are not on the list now have a button to add them again.
struct TripView: View {
    @Environment(AppModel.self) private var model
    let date: Date

    var body: some View {
        let trip = Suggestions.history(entries: model.store.entries).first { $0.date == date }
        List {
            if let trip {
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
                    Text(date, format: .relative(presentation: .named))
                }
            }
        }
        .navigationTitle(Text(date, format: .dateTime.day().month(.wide)))
    }
}

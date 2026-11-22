import GrailkaufCore
import SwiftUI

/// One past trip. Items that are not on the list now have a button to add them again.
struct TripView: View {
    @Environment(AppModel.self) private var model
    let date: Date

    var body: some View {
        let trip = Suggestions.history(entries: model.store.entries).first { $0.date == date }
        let missing = trip?.items.filter { !$0.onList }.map(\.text) ?? []
        List {
            if let trip {
                Section {
                    ForEach(missing, id: \.self) { text in
                        HStack {
                            Text(text)
                            Spacer()
                            Button("Add", systemImage: "plus.circle") { model.store.add(text) }
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
        .toolbar {
            if !missing.isEmpty {
                Button("Add all") { withAnimation { _ = model.store.add(missing.joined(separator: "\n")) } }
            }
        }
    }
}

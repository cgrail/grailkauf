import GrailkaufCore
import SwiftUI

/// A screen that the menu opens.
enum Route: Hashable {
    case trip(Date)
    case settings
}

/// The side menu, as in a mail app: the settings and the past trips, newest first.
struct MenuView: View {
    @Environment(AppModel.self) private var model
    let open: (Route) -> Void

    var body: some View {
        let trips = Suggestions.history(entries: model.store.entries)
        List {
            Button { open(.settings) } label: { Label("Settings", systemImage: "gearshape") }
            Section("History") {
                ForEach(trips, id: \.date) { trip in
                    Button { open(.trip(trip.date)) } label: { row(trip) }
                }
                if trips.isEmpty {
                    Text("Your shopping trips appear here after your first shop.").foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    /// The date, the first items, and how many items are not on the list now.
    private func row(_ trip: PastTrip) -> some View {
        let missing = trip.items.count { !$0.onList }
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.date, format: .dateTime.day().month(.wide)).font(.headline)
                Spacer()
                Text(trip.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(trip.items.map(\.text).joined(separator: ", "))
                .lineLimit(1)
                .foregroundStyle(.secondary)
            (missing == 0 ? Text("All on the list") : Text("\(missing) not on the list"))
                .font(.caption)
                .foregroundStyle(missing == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
    }
}

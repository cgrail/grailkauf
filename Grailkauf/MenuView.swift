import GrailkaufCore
import SwiftUI

/// A screen that the menu opens.
enum Route: Hashable {
    case trip(Date)
    case settings
}

/// The side menu, as in a mail app: a new list, the past trips and lists, newest first, and the settings at the bottom.
struct MenuView: View {
    @Environment(AppModel.self) private var model
    let open: (Route) -> Void
    @State private var confirmNewList = false

    var body: some View {
        let trips = Suggestions.history(entries: model.store.entries)
        let count = model.store.state.todo.count
        List {
            Button { confirmNewList = true } label: { Label("New list", systemImage: "square.and.pencil") }
                .disabled(count == 0)
                .confirmationDialog("Start a new list?", isPresented: $confirmNewList, titleVisibility: .visible) {
                    Button("New list") { withAnimation { model.store.archiveList() } }
                } message: {
                    Text("The current list with \(count) items moves to the history.")
                }
            Section("History") {
                ForEach(trips, id: \.date) { trip in
                    Button { open(.trip(trip.date)) } label: { row(trip) }
                }
                if trips.isEmpty {
                    Text("Your shopping trips appear here after your first shop.").foregroundStyle(.secondary)
                }
            }
        }
        // Pinned to the bottom, as in a mail app: a long history does not push it out of reach.
        .safeAreaInset(edge: .bottom) {
            Button { open(.settings) } label: { Label("Settings", systemImage: "gearshape") }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.bar)
        }
        .foregroundStyle(.primary)
    }

    /// The date and the items that are not on the list now: those are the ones the list can miss.
    private func row(_ trip: PastTrip) -> some View {
        let missing = trip.items.filter { !$0.onList }.map(\.text)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.date, format: .dateTime.day().month(.wide)).font(.headline)
                if trip.archived {
                    Label("Archived list", systemImage: "archivebox").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(trip.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if missing.isEmpty {
                Text("All on the list").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(missing.joined(separator: ", ")).lineLimit(3)
                Text("\(missing.count) not on the list, \(trip.items.count - missing.count) already on it")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
    }
}

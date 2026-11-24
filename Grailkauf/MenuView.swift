import GrailkaufCore
import SwiftUI

/// A screen that the menu opens.
enum Route: Hashable {
    case trip(Date)
    case settings
}

/// The side menu, as in a chat app: the past trips and lists, newest first, with "New list" and the settings at the bottom.
struct MenuView: View {
    @Environment(AppModel.self) private var model
    let open: (Route) -> Void
    let close: () -> Void

    var body: some View {
        let trips = Suggestions.history(entries: model.store.entries)
        let count = model.store.state.todo.count
        let ticked = model.store.state.rows.count - count
        List {
            Text("History")
                .font(.title.bold())
                .listRowSeparator(.hidden)
            ForEach(trips, id: \.date) { trip in
                Button { open(.trip(trip.date)) } label: { row(trip) }
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        if trip.archived {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                withAnimation { model.store.delete(trip.ids) }
                            }
                        }
                    }
            }
            if trips.isEmpty {
                Text("Your shopping trips appear here after your first shop.")
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        // A plain list is white only behind its rows. A short history then shows the list mode through the rest of the menu.
        .background(.background)
        // Pinned to the bottom, as in a chat app: a long history does not push the actions out of reach.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                // No question first: the old list stays in the history, and "Add all" there brings it back.
                action("New list", "square.and.pencil") {
                    withAnimation {
                        model.store.archiveList()
                        // The shop ends with the old list. The Live Activity then goes away.
                        model.mode = .list
                    }
                    close()
                }
                .disabled(count + ticked == 0)
                action("Settings", "gearshape") { open(.settings) }
            }
            .padding(.vertical, 8)
            .background(.background)
        }
        .foregroundStyle(.primary)
    }

    /// A plain row at the bottom of the menu: a large icon and a large title, as in a chat app.
    private func action(_ title: LocalizedStringKey, _ icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 16) {
                Image(systemName: icon).frame(width: 28)
                Text(title)
            }
            .font(.title3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
    }

    /// The date and the items that are not on the list now: those are the ones the list can miss.
    private func row(_ trip: PastTrip) -> some View {
        let missing = trip.items.filter { !$0.onList }.map(\.text)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(trip.date, format: .dateTime.day().month(.wide)).font(.headline)
                // An icon, not a text: the text broke into three lines next to the date.
                if trip.archived {
                    Image(systemName: "archivebox")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Archived list")
                }
                Spacer()
                Text(trip.date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if missing.isEmpty {
                Text("All on the list").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(missing.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(missing.count) not on the list, \(trip.items.count - missing.count) already on it")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 6)
    }
}

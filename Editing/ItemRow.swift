import GrailkaufCore
import SwiftUI

/// An item that edits in place, as in a notes app. Tap the text to change it. Enter or a tap elsewhere saves.
/// An emptied item goes away, and commas make more items. Touch and hold still drags the item.
struct ItemRow: View {
    let row: Row
    let store: Store
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            // The text is a button that fills the row, and a click on it does not drag.
            DragHandle()
            if editing {
                TextField("Item", text: $text)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { focused = false }
                    .onAppear { focused = true }
                    .onChange(of: focused) { if !focused { save() } }
            } else {
                Button {
                    text = row.text
                    editing = true
                } label: {
                    HStack {
                        Text(row.text)
                        Spacer()
                        RowDetails(row: row)
                    }
                    .contentShape(.rect)
                }
                .foregroundStyle(.primary)
            }
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete([row.id]) }
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
        }
        // Each button gets its own tap, not the whole row.
        .buttonStyle(.borderless)
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete([row.id]) }
        }
    }

    private func save() {
        editing = false
        store.edit(row, to: text)
    }
}

/// Settings, "Show details": the position of the item in the learned order and the picture of its section.
/// So the user can check what the app learned. A sparkle marks a guessed position, "?" an item with no section yet.
struct RowDetails: View {
    let row: Row
    @AppStorage("details") private var details = false

    var body: some View {
        if details {
            let position = row.isNew ? "–" : (row.sort + 1).formatted()
            HStack(spacing: 2) {
                Text(verbatim: position).monospacedDigit()
                if row.guessed { Image(systemName: "sparkles") }
                Text(verbatim: row.category.flatMap(GrailkaufCore.Category.init(rawValue:))?.emoji ?? "?")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Position \(position)"))
        }
    }
}

/// The Mac: a drag of a list row starts here. On the iPhone it is empty: touch and hold drags the row.
struct DragHandle: View {
    var body: some View {
        #if os(macOS)
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .contentShape(.rect)
            .pointerStyle(.grabIdle)
            .accessibilityHidden(true)
        #endif
    }
}

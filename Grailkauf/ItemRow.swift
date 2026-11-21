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
                    Text(row.text).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
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

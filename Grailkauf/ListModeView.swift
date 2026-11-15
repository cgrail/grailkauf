import GrailkaufCore
import SwiftUI

/// Writing the list, chat style: type, Enter, next. Items stay in the order they were added.
struct ListModeView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var editing: Row?
    @State private var editedText = ""
    @FocusState private var typing: Bool

    private var store: Store { model.store }

    var body: some View {
        let items = store.state.todo
        ScrollViewReader { scroll in
            List(items) { row in
                Button(row.text) {
                    editedText = row.text
                    editing = row
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { store.delete(row.id) }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "The list is empty", systemImage: "cart",
                        description: Text("Type below to add the first item."))
                }
            }
            .onChange(of: items.last?.id) { _, newest in
                if let newest { withAnimation { scroll.scrollTo(newest, anchor: .bottom) } }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .alert("Edit item", isPresented: .constant(editing != nil), presenting: editing) { row in
            TextField("Add item", text: $editedText)
            Button("Save") {
                let text = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { store.rename(row.id, to: text) }
                editing = nil
            }
            Button("Cancel", role: .cancel) { editing = nil }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            suggestions
            HStack(alignment: .bottom) {
                // Vertical, so pasted multi-line text survives; Enter arrives as a line break and adds the item.
                TextField("Add item", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .onChange(of: draft) { if draft.contains(where: \.isNewline) { add(draft) } }
                Button("Add", systemImage: "arrow.up.circle.fill") { add(draft) }
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    /// While typing: past items that match. Otherwise: what the household is due to buy again.
    @ViewBuilder private var suggestions: some View {
        let typed = !draft.trimmingCharacters(in: .whitespaces).isEmpty
        let texts = typed
            ? Suggestions.completions(for: draft, entries: store.entries)
            : Suggestions.due(entries: store.entries, now: .now)
        if !texts.isEmpty {
            ScrollView(.horizontal) {
                HStack {
                    if !typed {
                        Button("Fill with the usual") { store.add(texts.joined(separator: "\n")) }
                            .buttonStyle(.borderedProminent)
                    }
                    ForEach(texts, id: \.self) { text in
                        Button(text) {
                            store.add(text)
                            if typed { draft = "" }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .buttonBorderShape(.capsule)
        }
    }

    private func add(_ text: String) {
        store.add(text)
        draft = ""
        typing = true
    }
}

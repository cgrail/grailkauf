import GrailkaufCore
import SwiftUI

/// The screen to write the list, like a chat: type, press Enter, type the next item.
/// The items stay in the order in which they were added, until someone drags them.
struct ListModeView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var editing: Row?
    @State private var editedText = ""
    @State private var confirmingDeleteAll = false
    @State private var editMode = EditMode.inactive
    @State private var selection = Set<Row.ID>()
    @State private var dictation = Dictation()
    @FocusState private var typing: Bool

    private var store: Store { model.store }

    var body: some View {
        let items = store.state.todo
        ScrollViewReader { scroll in
            // In select mode, slide a finger down the circles to select many items, as in Photos.
            List(selection: $selection) {
                ForEach(items) { row in
                    if editMode.isEditing {
                        Text(row.text)
                    } else {
                        HStack {
                            Button {
                                editedText = row.text
                                editing = row
                            } label: {
                                Text(row.text).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                            }
                            .foregroundStyle(.primary)
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
                }
                .onMove { from, to in
                    if let source = from.first, let change = store.state.reordered(from: source, to: to) {
                        store.move(change.id, toCreatedAt: change.createdAt)
                    }
                }
            }
            .environment(\.editMode, $editMode)
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
        .toolbar {
            if editMode.isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.delete(selection)
                        selection = []
                    }
                    .disabled(selection.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        editMode = .inactive
                        selection = []
                    }
                }
            } else if !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select", systemImage: "checkmark.circle") { editMode = .active }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete all", systemImage: "xmark.bin") { confirmingDeleteAll = true }
                }
            }
        }
        .confirmationDialog("Delete all items?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { store.deleteAll() }
        }
        .onDisappear { if dictation.isRecording { finishDictation() } }
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
            if dictation.isRecording {
                Text(dictation.text.isEmpty ? String(localized: "Say your items…") : dictation.text)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                suggestions
            }
            HStack(alignment: .bottom) {
                // A vertical field keeps the lines of pasted text. Enter arrives as a line break and adds the item.
                TextField("Add item", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .onChange(of: draft) { if draft.contains(where: \.isNewline) { add(draft) } }
                Button("Add", systemImage: "arrow.up.circle.fill") { add(draft) }
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                Button(
                    dictation.isRecording ? "Stop" : "Dictate",
                    systemImage: dictation.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                ) {
                    if dictation.isRecording { finishDictation() } else { startDictation() }
                }
                .labelStyle(.iconOnly)
                .font(.title)
                .tint(dictation.isRecording ? .red : nil)
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

    private func startDictation() {
        typing = false
        Task {
            do { try await dictation.start() } catch { store.problem = error.localizedDescription }
        }
    }

    private func finishDictation() {
        Task {
            let items = await dictation.stop()
            if !items.isEmpty { store.add(items.joined(separator: "\n")) }
        }
    }

    private func add(_ text: String) {
        store.add(text)
        draft = ""
        typing = true
    }
}

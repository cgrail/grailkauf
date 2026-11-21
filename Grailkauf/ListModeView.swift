import GrailkaufCore
import SwiftUI

/// The screen to write the list, like a chat: type, press Enter, type the next item.
/// The items stay in the order in which they were added, until someone drags them.
struct ListModeView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var selection = Set<Row.ID>()
    @State private var dictation = Dictation()
    @State private var holding = false
    @State private var holdStart = Date.now
    @FocusState private var typing: Bool

    private var store: Store { model.store }

    var body: some View {
        let items = store.state.todo
        ScrollViewReader { scroll in
            // In select mode, slide a finger down the circles to select many items, as in Photos.
            List(selection: $selection) {
                ForEach(items) { row in
                    if model.selecting {
                        Text(row.text)
                    } else {
                        ItemRow(row: row, store: store)
                    }
                }
                .onMove { from, to in
                    if let source = from.first, let change = store.state.reordered(from: source, to: to) {
                        store.move(change.id, toCreatedAt: change.createdAt)
                    }
                }
            }
            .environment(\.editMode, .constant(model.selecting ? .active : .inactive))
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
        .overlay(alignment: .bottom) { repeatedNotice }
        .safeAreaInset(edge: .bottom) { if !model.selecting { composer } }
        // While selecting, only the buttons for the selection stay, as in a mail app.
        .navigationTitle(model.selecting ? Text("\(selection.count) selected") : Text(verbatim: ""))
        .toolbar {
            if model.selecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark", action: stopSelecting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    let all = Set(items.map(\.id))
                    Button(selection == all ? "Deselect all" : "Select all") {
                        selection = selection == all ? [] : all
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.delete(selection)
                        stopSelecting()
                    }
                    .disabled(selection.isEmpty)
                }
            } else if !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select", systemImage: "checkmark.circle") { model.selecting = true }
                }
            }
        }
        .onDisappear {
            if dictation.isRecording { finishDictation() }
            stopSelecting()
        }
        // An overlay, not a full screen cover: a cover would cancel the finger that holds the dictation button.
        .overlay {
            if dictation.isRecording {
                DictationScreen(dictation: dictation, holding: holding, stop: finishDictation)
            }
        }
        .toolbarVisibility(dictation.isRecording ? .hidden : .automatic, for: .navigationBar)

    }

    private var composer: some View {
        VStack(spacing: 8) {
            suggestions
            holdToDictate
            HStack(alignment: .bottom) {
                // A vertical field keeps the lines of pasted text. Enter arrives as a line break and adds the item.
                TextField("Add item", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.title3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.background, in: .rect(cornerRadius: 24))
                    .focused($typing)
                    .onChange(of: draft) { if draft.contains(where: \.isNewline) { add(draft) } }
                Button("Add", systemImage: "arrow.up.circle.fill") { add(draft) }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 44))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    /// Shows for a few seconds after an add replaced items that were on the list already.
    @ViewBuilder private var repeatedNotice: some View {
        if let names = store.repeated {
            Label("Already on the list: \(names)", systemImage: "info.circle")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: .capsule)
                .padding(.bottom, 8)
                .task(id: names) {
                    AccessibilityNotification.Announcement(String(localized: "Already on the list: \(names)")).post()
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { store.repeated = nil }
                }
        }
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

    private func stopSelecting() {
        model.selecting = false
        selection = []
    }

    /// Hold to dictate, let go to add the items. A short tap dictates hands-free, with a stop button.
    private var holdToDictate: some View {
        Label("Hold to dictate", systemImage: "mic.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.tint, in: .capsule)
            .scaleEffect(holding ? 1.1 : 1)
            .animation(.snappy, value: holding)
            // Reports the finger going down and up, also when the system cancels the touch. `perform` never runs.
            .onLongPressGesture(minimumDuration: 3600, maximumDistance: 10_000, perform: {}, onPressingChanged: hold)
            // VoiceOver cannot hold. A double tap starts hands-free dictation.
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { startDictation() }
    }

    private func hold(_ down: Bool) {
        holding = down
        if down {
            holdStart = .now
            startDictation()
        } else if dictation.isListening, Date.now.timeIntervalSince(holdStart) > 0.5 {
            finishDictation()
        }
        // A short tap, or a hold that ended in the permission prompt, keeps listening hands-free.
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

/// An item that edits in place, as in a notes app. Tap the text to change it. Enter or a tap elsewhere saves.
/// An emptied item goes away, and commas make more items. Touch and hold still drags the item.
private struct ItemRow: View {
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
        let parts = ItemName.split(text)
        if parts.isEmpty {
            store.delete([row.id])
        } else if parts != [row.text] {
            store.split(row.id, into: parts)
        }
    }
}

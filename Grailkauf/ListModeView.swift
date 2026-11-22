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
    /// The "Sections" tab: the items as tiles by supermarket section.
    let grid: Bool
    @FocusState private var typing: Bool
    /// A tap on a suggestion below the list adds an item without the scroll to it, so the next suggestion stays under the finger.
    @State private var stayPut = false

    private var store: Store { model.store }

    var body: some View {
        let items = store.state.todo
        let past = pastSuggestions
        Group {
            if grid {
                // The learned order, as in shop mode: the grid is a map of the store, not a history of the list.
                CategoryGrid(store: store, sections: Grid.sections(store.state.shop(now: .now), order: store.state.sectionOrder))
            } else {
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
                        if !model.selecting, !past.isEmpty {
                            Section("Suggestions") {
                                ForEach(past, id: \.self) { text in
                                    Button { stayPut = store.add(text) } label: {
                                        Label(text, systemImage: "plus.circle").foregroundStyle(.secondary)
                                    }
                                    // For a thing bought once. It comes back if a later trip or list has it.
                                    .swipeActions {
                                        Button("Remove", systemImage: "xmark", role: .destructive) {
                                            model.removedSuggestions[ItemName.key(text)] = .now
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .environment(\.editMode, .constant(model.selecting ? .active : .inactive))
                    .onChange(of: items.last?.id) { _, newest in
                        if stayPut {
                            stayPut = false
                        } else if let newest {
                            withAnimation { scroll.scrollTo(newest, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .overlay {
            if items.isEmpty, grid || past.isEmpty {
                ContentUnavailableView(
                    "The list is empty", systemImage: "cart", description: Text("Type below to add the first item."))
            }
        }
        .overlay(alignment: .bottom) { repeatedNotice }
        // An overlay, not a full screen cover: a cover would cancel the finger that holds the dictation button.
        // It covers the list only. The bar with the button stays visible below it.
        .overlay {
            if dictation.isRecording {
                DictationScreen(dictation: dictation, holding: holding)
            }
        }
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
            } else if !items.isEmpty, !grid {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select", systemImage: "checkmark.circle") { model.selecting = true }
                }
            }
        }
        .onDisappear {
            if dictation.isRecording { finishDictation() }
            stopSelecting()
        }
        .toolbarVisibility(dictation.isRecording ? .hidden : .automatic, for: .navigationBar)

    }

    private var composer: some View {
        // Only the rows above the button change while dictating, so the button stays under the finger.
        VStack(spacing: 8) {
            if dictation.isRecording {
                RecordingStatus(dictation: dictation)
            } else if !grid {
                suggestions
            }
            if model.classifying, !dictation.isRecording {
                // The model splits and sorts new items in the background. They can still change.
                Label {
                    Text("Checking the new items…")
                } icon: {
                    ProgressView()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            // One line, as in a chat app: the text field, and the microphone on the right.
            HStack(alignment: .bottom) {
                textField
                holdToDictate
            }
        }
        // Without the text field, the bar would shrink to the width of the dictation button.
        .frame(maxWidth: .infinity)
        .padding()
        .background(.bar)
    }

    private var textField: some View {
        // A vertical field keeps the lines of pasted text. Enter arrives as a line break and adds the item.
        TextField("Add item", text: $draft, axis: .vertical)
            .lineLimit(1...4)
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.background, in: .rect(cornerRadius: 24))
            .focused($typing)
            .onChange(of: draft) { if draft.contains(where: \.isNewline) { add(draft) } }
            .opacity(dictation.isRecording ? 0 : 1)
            .disabled(dictation.isRecording)
            // An overlay keeps the height of the line, so the button stays under the finger.
            .overlay { if dictation.isRecording { RecordingBar(dictation: dictation) } }
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

    /// Below the items: what the past lists had, without the due items that the bar above the text field shows.
    private var pastSuggestions: [String] {
        let due = Set(Suggestions.due(entries: store.entries, now: .now))
        return Suggestions.fromPastLists(entries: store.entries, removed: model.removedSuggestions)
            .filter { !due.contains($0) }
    }

    private func stopSelecting() {
        model.selecting = false
        selection = []
    }

    /// Hold to dictate, let go to add the items. While held, the button is red and glows.
    private var holdToDictate: some View {
        Label(holding ? "Let go to add" : "Hold to dictate", systemImage: "mic.fill")
            .labelStyle(.iconOnly)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(.tint, in: .circle)
            .background { if holding { PulseRings(level: dictation.levels.last ?? 0) } }
            .shadow(color: .red.opacity(holding ? 0.7 : 0), radius: 12)
            .tint(holding ? .red : nil)
            .scaleEffect(holding ? 1.15 : 1)
            .animation(.snappy, value: holding)
            // Reports the finger going down and up, also when the system cancels the touch. `perform` never runs.
            .onLongPressGesture(minimumDuration: 3600, maximumDistance: 10_000, perform: {}, onPressingChanged: hold)
            // With VoiceOver, a double tap and hold passes the press through.
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap and hold, then speak.")
    }

    private func hold(_ down: Bool) {
        holding = down
        if down { startDictation() } else { finishDictation() }
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

    /// The "Sections" tab goes to the list: the new item shows at the end, and the keyboard stays for the next one.
    private func add(_ text: String) {
        store.add(text)
        draft = ""
        typing = true
        if grid { withAnimation { model.mode = .list } }
    }
}

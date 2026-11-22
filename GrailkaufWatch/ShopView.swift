import GrailkaufCore
import SwiftUI

struct ShopView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let now = Date.now
        let open = model.state.shop(now: now)
        let done = model.state.done(now: now)
        let total = done.count + open.count
        NavigationStack {
            List {
                if let current = open.first {
                    ForEach(Grid.shopSections(open), id: \.category) { section in
                        Section {
                            ForEach(section.rows) { row in
                                if row.id == current.id {
                                    Button { model.tick(row.id) } label: { item(row).font(.headline) }
                                        .handGestureShortcut(.primaryAction)
                                        .swipeActions { later(row) }
                                } else {
                                    Button { model.tick(row.id) } label: { item(row) }
                                        .swipeActions { later(row) }
                                }
                            }
                        } header: {
                            section.category.label
                        }
                    }
                } else if !model.hasData {
                    Text("Open Grailkauf on your iPhone to load the list.")
                } else {
                    if done.isEmpty {
                        Text("The list is empty.")
                    } else {
                        VStack {
                            Text("🎉").font(.system(size: 60)).accessibilityHidden(true)
                            Text("All done.").font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }
                }
                if !done.isEmpty {
                    // By section, as the open items. Within a section, the most recent tick is first.
                    Section("Done") {
                        ForEach(Grid.sections(done), id: \.category) { section in
                            section.category.label.foregroundStyle(.secondary)
                            ForEach(section.rows) { row in
                                Button {
                                    model.untick(row.id)
                                } label: {
                                    item(row, ticked: true).strikethrough().foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                // At the end, so the top shows only the time, the progress and the current item.
                Section {
                    NavigationLink { InfoView() } label: { Label("Info", systemImage: "info.circle") }
                }
            }
            // Small text, low rows and little space between sections, so more than two items fit on one screen.
            .font(.footnote)
            .environment(\.defaultMinListRowHeight, 32)
            .listSectionSpacing(.compact)
            .toolbar {
                if total > 0 {
                    // Small, in the corner across from the time, so the current item is on the first screen.
                    ToolbarItem(placement: .topBarLeading) {
                        Progress(done: done.count, total: total)
                            // shortcut: the toolbar row sits lower than the time; a fixed nudge lifts it level. Recheck on a new watchOS.
                            .offset(y: -10)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("\(done.count)/\(total)"))
                    }
                }
            }
        }
        // The app gets the list from the phone when it opens. The list is then current before the first tick.
        .onChange(of: scenePhase, initial: true) { if scenePhase == .active { Task { _ = await model.refresh() } } }
    }

    /// An empty box for an open item, a tick for a done one, then the picture of the item or of its section.
    private func item(_ row: Row, ticked: Bool = false) -> some View {
        let section = GrailkaufCore.Category(rawValue: row.category ?? "") ?? .other
        return HStack(spacing: 6) {
            Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ticked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(ItemName.emoji(row.text) ?? section.emoji)
            Text(row.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.text)
        .accessibilityAddTraits(ticked ? .isSelected : [])
    }

    private func later(_ row: Row) -> some View {
        Button("Later", systemImage: "arrow.uturn.down") { model.later(row.id) }
    }
}

/// A ring and a count in the font of the time, as tall as its digits, so both read as one line with the time.
private struct Progress: View {
    let done: Int
    let total: Int
    private let font = UIFont.systemFont(ofSize: 17, weight: .medium)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ZStack {
                Circle().inset(by: 1).stroke(.secondary, lineWidth: 2)
                Circle().inset(by: 1).trim(from: 0, to: Double(done) / Double(total))
                    .stroke(.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: font.capHeight, height: font.capHeight)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            Text("\(done)/\(total)").font(Font(font)).monospacedDigit()
        }
    }
}

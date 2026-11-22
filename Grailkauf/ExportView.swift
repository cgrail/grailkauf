import GrailkaufCore
import SwiftUI

/// The open items as text for a notes app, in shop order, one item per line. A switch per section leaves it out.
struct ExportView: View {
    @Environment(AppModel.self) private var model
    @State private var excluded: Set<GrailkaufCore.Category> = []

    var body: some View {
        let state = model.store.state
        let sections = Grid.sections(state.shop(now: .now), order: state.sectionOrder)
        let text = Grid.text(sections, without: excluded)
        List {
            Section {
                ForEach(sections, id: \.category) { section in
                    Toggle(isOn: Binding(
                        get: { !excluded.contains(section.category) },
                        set: { if $0 { excluded.remove(section.category) } else { excluded.insert(section.category) } }
                    )) {
                        Label { Text(section.category.title) } icon: { Text(section.category.emoji) }
                    }
                }
            } footer: {
                Text("In Notes, select the text and tap the checklist button. Each item then gets a circle to tick.")
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView("Export", systemImage: "square.and.arrow.up", description: Text("The list is empty."))
            }
        }
        .toolbar {
            ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }
                .disabled(text.isEmpty)
        }
        .navigationTitle("Export")
    }
}

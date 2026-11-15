// TEMPORARY verification aid. Deleted before hand-over.
import ActivityKit
import CoreData
import FoundationModels
import Foundation
import GrailkaufCore

extension AppModel {
    func runScript() {
        guard let script = ProcessInfo.processInfo.environment["GK_SCRIPT"] else { return }
        Task {
            for command in script.split(separator: "|") {
                let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
                let argument = parts.count > 1 ? parts[1] : ""
                let row: (String) -> Row? = { name in self.store.state.rows.first { $0.name == name } }
                switch parts[0] {
                case "seed": seed()
                case "add": store.add(argument)
                case "tick": if let row = row(argument) { store.setTicked(row.id, true) }
                case "untick": if let row = row(argument) { store.setTicked(row.id, false) }
                case "later": if let row = row(argument) { store.later(row.id) }
                case "mode": mode = Mode(rawValue: argument) ?? .list
                case "move":
                    let keys = argument.split(separator: ">").map(String.init)
                    store.move(keys[0], after: keys.count > 1 ? keys[1] : nil)
                case "wait": try? await Task.sleep(for: .seconds(Double(argument) ?? 1))
                case "info":
                    gk("GK model available:", Classifier.isAvailable, "activities:", Activity<ShoppingAttributes>.activities.count,
                          "categories:", store.entries.filter { $0.tickedAt == nil }.map { "\($0.text)=\($0.category ?? "nil")" },
                          "due:", Suggestions.due(entries: store.entries, now: .now))
                default: break
                }
                try? await Task.sleep(for: .milliseconds(300))
                store.refresh()
                gk("GK", command, "→ shop:", store.state.shop(now: .now).map { "\($0.name)\($0.isNew ? "[new]" : "")\($0.guessed ? "[guess]" : "")" },
                      "done:", store.state.done(now: .now).map(\.name), "order:", store.order)
            }
        }
    }

    private func seed() {
        let context = store.container.viewContext
        guard let list = store.activeList(), let persistent = list.objectID.persistentStore else { return }
        for weeksAgo in [4.0, 3, 2, 1] {
            let start = Date.now.addingTimeInterval(-weeksAgo * 7 * 86_400)
            for (index, name) in ["Äpfel", "Bananen", "Brot", "2 Milch", "Käse", "Pfeffer", "Cola"].enumerated() {
                let item = Item(context: context)
                context.assign(item, to: persistent)
                item.id = UUID()
                item.text = name
                item.category = name == "Pfeffer" ? "spices" : nil
                item.createdAt = start.addingTimeInterval(-3600)
                item.modifiedAt = start
                item.tickedAt = start.addingTimeInterval(Double(index) * 60)
                item.list = list
            }
        }
        try? context.save()
    }
}

func gk(_ items: Any...) {
    NSLog("%@", items.map { "\($0)" }.joined(separator: " "))
}

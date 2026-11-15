// TEMPORARY verification aid. Deleted before hand-over.
import Foundation

extension WatchModel {
    func runScript() {
        guard let script = ProcessInfo.processInfo.environment["GK_SCRIPT"] else { return }
        Task {
            for command in script.split(separator: "|") {
                try? await Task.sleep(for: .seconds(3))
                let now = Date.now
                switch command {
                case "tick": if let row = state.shop(now: now).first { tick(row.id) }
                case "later": if let row = state.shop(now: now).first { later(row.id) }
                case "untick": if let row = state.done(now: now).first { untick(row.id) }
                case "refresh": NSLog("GKW refresh reachable: %d", await refresh() ? 1 : 0)
                default: break
                }
                NSLog("%@", "GKW \(command) → shop: \(state.shop(now: now).map(\.name)) done: \(state.done(now: now).map(\.name))")
            }
        }
    }
}

import GrailkaufCore
import SwiftUI
import WatchKit

@main
struct GrailkaufWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            ShopView().environment(model)
        }
    }
}

/// The Watch has two sources for the list: its own iCloud copy and the list from the phone.
/// `ListState.onWatch` combines them.
@MainActor @Observable
final class WatchModel {
    private(set) var state = ListState()
    /// False until either source has delivered anything.
    private(set) var hasData = false

    @ObservationIgnored private let store = Store(ownsList: false)
    @ObservationIgnored private let link = Link()
    /// The last list from the phone, with the ticks made on the Watch since then.
    @ObservationIgnored private var phone = UserDefaults.standard.data(forKey: "phone")
        .flatMap({ try? JSONDecoder().decode(ListState.self, from: $0) })
    {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(phone), forKey: "phone") }
    }

    init() {
        store.onChange = { [unowned self] in recompute() }
        link.onReceive = { [unowned self] incoming in
            // Keep the ticks that the phone does not know yet.
            phone = incoming.updated(from: phone?.rows ?? [])
            recompute()
        }
        link.current = { [unowned self] in state }
        link.start()
        store.refresh()
    }

    private func recompute() {
        let own = store.entries.isEmpty ? nil : store.state
        let merged = ListState.onWatch(
            phone: phone, own: own, ownVersions: store.rows(for: Set(phone?.rows.map(\.id) ?? [])))
        if merged != state { state = merged }
        hasData = phone != nil || own != nil
    }

    func tick(_ id: UUID) {
        WKInterfaceDevice.current().play(.click)
        edit { $0.tick(id, at: .now) }
    }

    func untick(_ id: UUID) { edit { $0.untick(id, at: .now) } }

    func later(_ id: UUID) { edit { $0.later(id, at: .now) } }

    private func edit(_ change: (inout ListState) -> Void) {
        var edited = state
        change(&edited)
        // Write the change into both sources: the phone copy goes over Bluetooth, the store goes to iCloud.
        phone = phone?.updated(from: edited.rows)
        store.apply(edited.rows)
        store.refresh()
        link.send(state)
    }

    /// Reads the store again and asks the phone for its list. False if the phone is not reachable.
    func refresh() async -> Bool {
        store.refresh()
        return await link.pull()
    }
}

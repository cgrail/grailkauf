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

/// The Watch has two sources for the list: its own iCloud copy and what the iPhone tells it over Bluetooth.
/// Whichever saw iCloud last decides which items are on the list; for each item the newer change wins.
@MainActor @Observable
final class WatchModel {
    private(set) var state = ListState()
    /// False until either source has delivered anything.
    private(set) var hasData = false

    @ObservationIgnored private let store = Store(ownsList: false)
    @ObservationIgnored private let link = Link()
    /// The iPhone's list as last received, plus our own ticks since.
    @ObservationIgnored private var phone = UserDefaults.standard.data(forKey: "phone")
        .flatMap({ try? JSONDecoder().decode(ListState.self, from: $0) })
    {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(phone), forKey: "phone") }
    }

    init() {
        store.onChange = { [unowned self] in recompute() }
        link.onReceive = { [unowned self] incoming in
            // Keep ticks the iPhone has not heard of yet.
            phone = incoming.updated(from: phone?.rows ?? [])
            recompute()
        }
        link.current = { [unowned self] in state }
        link.start()
        store.refresh()
        runScript() // TEMP
    }

    private func recompute() {
        var merged: ListState
        if let phone, store.entries.isEmpty || (phone.lastSync ?? .distantPast) >= (store.lastSync ?? .distantPast) {
            merged = phone.updated(from: store.rows(for: Set(phone.rows.map(\.id))))
        } else {
            merged = store.state.updated(from: phone?.rows ?? [])
        }
        merged.lastSync = [phone?.lastSync, store.lastSync].compactMap(\.self).max()
        if merged != state { state = merged }
        hasData = phone != nil || !store.entries.isEmpty
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
        // Into both sources, wherever the item exists: the iPhone copy for Bluetooth, our store for iCloud.
        phone = phone?.updated(from: edited.rows)
        store.apply(edited.rows)
        store.refresh()
        link.send(state)
    }

    /// Re-reads the store and asks the iPhone for its list. False when the iPhone cannot be reached.
    func refresh() async -> Bool {
        store.refresh()
        return await link.pull()
    }
}

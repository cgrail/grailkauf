import CloudKit
import GrailkaufCore
import SwiftUI

@main
struct GrailkaufApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView().environment(AppModel.shared)
        }
    }
}

enum Mode: String {
    case list, shop
}

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    let store = Store(ownsList: true)
    /// Stored, so that a launch in the background still knows that a shop is in progress.
    var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .list {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "mode")
            ShoppingActivity.sync(store.state, shopping: mode == .shop)
        }
    }
    /// An invitation that waits for the user to confirm. The shared list replaces the own list.
    var invite: CKShare.Metadata?
    /// True while the user selects items in list mode. The other buttons at the top then go away.
    var selecting = false

    @ObservationIgnored private let link = Link()
    /// True while the language model splits and sorts new items.
    private(set) var classifying = false
    /// The items that the model got since launch. The app then asks only once for an item that fails.
    @ObservationIgnored private var asked: Set<UUID> = []
    /// Lines of a shared note. The user wrote each line as one item, so the model does not split it.
    @ObservationIgnored private var sharedTexts: Set<String> = []

    private init() {
        store.onChange = { [unowned self] in changed() }
        link.onReceive = { [unowned self] in store.apply($0.rows) }
        link.current = { [unowned self] in store.state }
        link.start()
        store.refresh()
    }

    private func changed() {
        takeShared()
        link.send(store.state)
        ShoppingActivity.sync(store.state, shopping: mode == .shop)
        Task { await classify() }
    }

    /// Adds the text from the share extension. Each refresh checks: on launch, on open and after an iCloud sync.
    private func takeShared() {
        // While an error shows, no retry: a failed save refreshes again.
        guard store.problem == nil, let inbox = UserDefaults(suiteName: Inbox.group), let text = Inbox.text(in: inbox)
        else { return }
        // The text stays in the inbox until the items are saved.
        guard store.add(text) else { return }
        Inbox.remove(text, from: inbox)
        sharedTexts.formUnion(ItemName.split(text))
    }

    /// Splits each new item into the products in it, then gives it a category.
    /// Shop mode can then place an item that it does not know.
    private func classify() async {
        guard !classifying, Classifier.isAvailable else { return }
        classifying = true
        defer { classifying = false }
        func isNew(_ entry: Entry) -> Bool { entry.tickedAt == nil && entry.category == nil && !asked.contains(entry.id) }
        // Items that arrive while the model works get their turn in the next round.
        while case let new = store.entries.filter(isNew), !new.isEmpty {
            for entry in new {
                asked.insert(entry.id)
                var text = entry.text
                let shared = sharedTexts.remove(text) != nil
                if !shared, text.split(separator: " ").count > 1, let parts = await Classifier.items(in: text), parts.count > 1 {
                    store.split(entry.id, into: parts)
                    text = parts[0]
                }
                if let category = await Classifier.category(of: ItemName.display(text)) {
                    store.setCategory(entry.id, category.rawValue)
                }
            }
            store.refresh()
        }
    }

    // MARK: Sharing

    func received(_ invitation: CKShare.Metadata) {
        if store.state.todo.isEmpty { join(invitation) } else { invite = invitation }
    }

    func join(_ invitation: CKShare.Metadata) {
        Task {
            do {
                try await store.accept(invitation)
            } catch {
                store.problem = error.localizedDescription
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Create the app model also on a background launch. The ticks from the Watch then reach iCloud.
        _ = AppModel.shared
        return true
    }

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Receives the invitation when someone taps a share link.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let invitation = options.cloudKitShareMetadata { AppModel.shared.received(invitation) }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith invitation: CKShare.Metadata) {
        AppModel.shared.received(invitation)
    }
}

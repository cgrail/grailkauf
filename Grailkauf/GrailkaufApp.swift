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
    /// Remembered so that a launch in the background (woken by the Watch) still knows a shop is in progress.
    var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .list {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "mode")
            ShoppingActivity.sync(store.state, shopping: mode == .shop)
        }
    }
    /// An invitation waiting for the user to confirm that it replaces their own list.
    var invite: CKShare.Metadata?

    @ObservationIgnored private let link = Link()
    @ObservationIgnored private var classifying = false
    /// Items the model was already asked about since launch, so a failing one is not asked on every change.
    @ObservationIgnored private var asked: Set<UUID> = []

    private init() {
        store.onChange = { [unowned self] in changed() }
        link.onReceive = { [unowned self] in store.apply($0.rows) }
        link.current = { [unowned self] in store.state }
        link.start()
        store.refresh()
        runScript() // TEMP
    }

    private func changed() {
        link.send(store.state)
        ShoppingActivity.sync(store.state, shopping: mode == .shop)
        Task { await classify() }
    }

    /// Gives every open item without a category one, so shop mode can place items it has never seen.
    private func classify() async {
        guard !classifying, Classifier.isAvailable else { return }
        classifying = true
        defer { classifying = false }
        for entry in store.entries where entry.tickedAt == nil && entry.category == nil && asked.insert(entry.id).inserted {
            if let category = await Classifier.category(of: ItemName.display(entry.text)) {
                store.setCategory(entry.id, category.rawValue)
            }
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
        // Also on a background launch, so ticks from the Watch are taken over and sent to iCloud.
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

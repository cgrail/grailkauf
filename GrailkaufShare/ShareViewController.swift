import GrailkaufCore
import SwiftUI
import UniformTypeIdentifiers

/// "Grailkauf" in the share sheet. It keeps the shared text in the inbox and opens the app on the list.
/// The app adds the items when it opens.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await receive() }
    }

    private func receive() async {
        guard let text = await sharedText(), let defaults = UserDefaults(suiteName: Inbox.group) else {
            extensionContext?.cancelRequest(withError: CocoaError(.fileReadUnknown))
            return
        }
        Inbox.put(text, in: defaults)
        if openList() {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        show(Confirmation(count: ItemName.split(text).count))
        try? await Task.sleep(for: .seconds(2))
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// An extension cannot call `UIApplication.open`, so this finds the app in the responder chain
    /// and calls the method by its name. False if no app object is in the chain.
    private func openList() -> Bool {
        typealias Open = @convention(c) (
            AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?
        ) -> Void
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard let url = NSURL(string: "grailkauf://list"),
            let app = sequence(first: self as UIResponder, next: \.next).first(where: { $0 is UIApplication }),
            app.responds(to: selector)
        else { return false }
        unsafeBitCast(app.method(for: selector), to: Open.self)(app, selector, url, [:] as NSDictionary, nil)
        return true
    }

    private func sharedText() async -> String? {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let type = UTType.plainText.identifier
        for provider in items.flatMap({ $0.attachments ?? [] }) where provider.hasItemConformingToTypeIdentifier(type) {
            switch try? await provider.loadItem(forTypeIdentifier: type) {
            case let text as String: return text
            case let data as Data: return String(decoding: data, as: UTF8.self)
            default: continue
            }
        }
        return items.lazy.compactMap { $0.attributedContentText?.string }.first
    }

    private func show(_ view: some View) {
        let host = UIHostingController(rootView: view)
        addChild(host)
        host.view.frame = self.view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

private struct Confirmation: View {
    let count: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("\(count) items added")
                .font(.headline)
            Text("Other devices get them when Grailkauf opens on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

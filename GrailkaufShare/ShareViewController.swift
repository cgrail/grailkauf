import GrailkaufCore
import SwiftUI
import UniformTypeIdentifiers

/// "Grailkauf" in the share sheet. It keeps the shared text in the inbox and shows the number of items.
/// The app adds the items when it runs next.
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
        show(Confirmation(count: ItemName.split(text).count))
        try? await Task.sleep(for: .seconds(2))
        extensionContext?.completeRequest(returningItems: nil)
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

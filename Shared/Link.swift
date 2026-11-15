import Foundation
import GrailkaufCore
import WatchConnectivity

/// The Bluetooth path between iPhone and Watch, which works with no internet.
///
/// Each side sends its whole current list and the receiver keeps the newer change per item, so a message that
/// arrives twice, late or out of order does no harm.
@MainActor
final class Link: NSObject, WCSessionDelegate {
    var onReceive: (ListState) -> Void = { _ in }
    /// What to send when the other side asks or the connection comes up.
    var current: () -> ListState? = { nil }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ state: ListState) {
        let session = WCSession.default
        guard session.activationState == .activated, let data = try? JSONEncoder().encode(state) else { return }
        // Kept by the system until the other app next runs.
        try? session.updateApplicationContext(["state": data])
        // Arrives within a second while both apps are open.
        if session.isReachable { session.sendMessage(["state": data], replyHandler: nil) }
    }

    /// Asks the other side for its list right now. False when it cannot be reached.
    func pull() async -> Bool {
        guard WCSession.default.isReachable else { return false }
        return await withCheckedContinuation { continuation in
            WCSession.default.sendMessage(
                ["pull": true],
                replyHandler: { reply in
                    self.received(reply)
                    continuation.resume(returning: true)
                },
                errorHandler: { _ in continuation.resume(returning: false) })
        }
    }

    nonisolated private func received(_ payload: [String: Any]) {
        guard let data = payload["state"] as? Data, let state = try? JSONDecoder().decode(ListState.self, from: data)
        else { return }
        Task { @MainActor in onReceive(state) }
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {
        received(session.receivedApplicationContext)
        Task { @MainActor in
            if let state = current() { send(state) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        received(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        received(message)
    }

    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void
    ) {
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            let data = current().flatMap { try? JSONEncoder().encode($0) }
            reply(data.map { ["state": $0] } ?? [:])
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}

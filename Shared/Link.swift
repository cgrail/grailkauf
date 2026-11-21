import Foundation
import GrailkaufCore
import WatchConnectivity

/// The Bluetooth path between the phone and the Watch. It needs no internet.
///
/// Each side sends its full current list. The receiver keeps the newer change for each item.
/// So a message that arrives twice, late or in the wrong order does no harm.
@MainActor
final class Link: NSObject, WCSessionDelegate {
    var onReceive: (ListState) -> Void = { _ in }
    /// The list to send when the other side asks or the connection starts.
    var current: () -> ListState? = { nil }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ state: ListState) {
        let session = WCSession.default
        guard session.activationState == .activated, let data = try? JSONEncoder().encode(state) else { return }
        // The system keeps this until the other app runs again.
        try? session.updateApplicationContext(["state": data])
        // This arrives in about a second while both apps are open.
        if session.isReachable { session.sendMessage(["state": data], replyHandler: nil) }
    }

    /// Asks the other side for its list now. False if the other side is not reachable.
    func pull() async -> Bool {
        guard WCSession.default.isReachable else { return false }
        return await withCheckedContinuation { continuation in
            // @Sendable: WatchConnectivity calls these on its own queue, not the main actor.
            WCSession.default.sendMessage(
                ["pull": true],
                replyHandler: { @Sendable reply in
                    self.received(reply)
                    continuation.resume(returning: true)
                },
                errorHandler: { @Sendable _ in continuation.resume(returning: false) })
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

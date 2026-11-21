import ActivityKit
import GrailkaufCore
import UIKit

/// Shows the list on the Lock Screen as a Live Activity.
/// The activity runs while the phone is in shop mode and items are left. It needs no internet.
@MainActor
enum ShoppingActivity {
    private static var pending: Task<Void, Never>?

    static func sync(_ state: ListState, shopping: Bool) {
        let now = Date.now
        let open = state.shop(now: now), done = state.done(now: now)
        let content = ActivityContent(
            state: ShoppingAttributes.ContentState(
                done: done.count, total: done.count + open.count, current: open.first?.text,
                next: open.dropFirst().prefix(3).map(\.name)),
            staleDate: now.addingTimeInterval(OrderLearning.tripGap))
        let canStart = UIApplication.shared.applicationState == .active
            && ActivityAuthorizationInfo().areActivitiesEnabled
        let stop = !shopping, finished = open.isEmpty

        // The updates run one after the other. An older update can then never replace a newer one.
        let previous = pending
        pending = Task {
            await previous?.value
            await apply(content, stop: stop, finished: finished, canStart: canStart)
        }
    }

    nonisolated private static func apply(
        _ content: ActivityContent<ShoppingAttributes.ContentState>, stop: Bool, finished: Bool, canStart: Bool
    ) async {
        // An ended activity stays in the list while it lingers on screen, and ignores updates.
        let all = Activity<ShoppingAttributes>.activities
        let running = all.filter { $0.activityState == .active || $0.activityState == .stale }
        if stop {
            for activity in all { await activity.end(nil, dismissalPolicy: .immediate) }
        } else if finished {
            let linger = ActivityUIDismissalPolicy.after(.now.addingTimeInterval(600))
            for activity in running { await activity.end(content, dismissalPolicy: linger) }
        } else if running.isEmpty {
            // Items are open again: take down a lingering "All done" before showing the list.
            for activity in all { await activity.end(nil, dismissalPolicy: .immediate) }
            if canStart { _ = try? Activity.request(attributes: ShoppingAttributes(), content: content) }
        } else {
            for activity in running { await activity.update(content) }
        }
    }
}

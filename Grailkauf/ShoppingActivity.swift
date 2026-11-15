import ActivityKit
import GrailkaufCore
import UIKit

/// Keeps the Lock Screen Live Activity in step with the list. It runs while the iPhone is in shop mode and
/// something is left to buy, and is driven locally, so it needs no internet.
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

        // One after the other, so an older update can never overtake a newer one.
        let previous = pending
        pending = Task {
            await previous?.value
            await apply(content, stop: stop, finished: finished, canStart: canStart)
        }
    }

    nonisolated private static func apply(
        _ content: ActivityContent<ShoppingAttributes.ContentState>, stop: Bool, finished: Bool, canStart: Bool
    ) async {
        let running = Activity<ShoppingAttributes>.activities
        if stop {
            for activity in running { await activity.end(nil, dismissalPolicy: .immediate) }
        } else if finished {
            let linger = ActivityUIDismissalPolicy.after(.now.addingTimeInterval(600))
            for activity in running { await activity.end(content, dismissalPolicy: linger) }
        } else if running.isEmpty {
            if canStart { _ = try? Activity.request(attributes: ShoppingAttributes(), content: content) }
        } else {
            for activity in running { await activity.update(content) }
        }
    }
}

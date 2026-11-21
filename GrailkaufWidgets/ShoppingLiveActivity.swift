import ActivityKit
import SwiftUI
import WidgetKit

@main
struct GrailkaufWidgets: WidgetBundle {
    var body: some Widget {
        ShoppingLiveActivity()
    }
}

/// Display only: tapping it opens the list in shop mode.
struct ShoppingLiveActivity: Widget {
    private let shop = URL(string: "grailkauf://shop")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingAttributes.self) { context in
            LockScreen(state: context.state).widgetURL(shop)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Progress(state: context.state) }
                DynamicIslandExpandedRegion(.bottom) { Items(state: context.state) }
            } compactLeading: {
                Image(systemName: "cart")
            } compactTrailing: {
                Text("\(context.state.done)/\(context.state.total)").monospacedDigit()
            } minimal: {
                Text("\(context.state.total - context.state.done)").monospacedDigit()
            }
            .widgetURL(shop)
        }
        // The Apple Watch Smart Stack shows the small family.
        .supplementalActivityFamilies([.small, .medium])
    }
}

private struct LockScreen: View {
    @Environment(\.activityFamily) private var family
    let state: ShoppingAttributes.ContentState

    var body: some View {
        if family == .small {
            VStack(alignment: .leading, spacing: 4) {
                Progress(state: state)
                Text(state.current ?? String(localized: "All done.")).font(.headline).lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Progress(state: state)
                Items(state: state)
            }
            .padding()
        }
    }
}

private struct Progress: View {
    let state: ShoppingAttributes.ContentState

    var body: some View {
        HStack {
            Image(systemName: "cart")
            ProgressView(value: Double(state.done), total: Double(max(state.total, 1)))
            Text("\(state.done) / \(state.total)").monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Items: View {
    let state: ShoppingAttributes.ContentState

    var body: some View {
        if let current = state.current {
            VStack(alignment: .leading, spacing: 2) {
                Text(current).font(.title3.bold())
                if !state.next.isEmpty {
                    Text(state.next.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("All done.").frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

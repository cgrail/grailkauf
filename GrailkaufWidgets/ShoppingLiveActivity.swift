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
            VStack(alignment: .leading, spacing: 8) {
                Progress(state: context.state)
                Items(state: context.state)
            }
            .padding()
            .widgetURL(shop)
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

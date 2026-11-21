import SwiftUI

/// Fills the screen while the phone listens. Each item shows on its own line as soon as the phone understands it.
struct DictationScreen: View {
    let dictation: Dictation
    let stop: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            let items = dictation.items
            if items.isEmpty {
                Text("Say your items…")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                List(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item).font(.title2)
                }
                .defaultScrollAnchor(.bottom)
            }
            Text("Say “fertig” or “done” to finish.")
                .foregroundStyle(.secondary)
            Button("Stop", systemImage: "stop.circle.fill", action: stop)
                .labelStyle(.iconOnly)
                .font(.system(size: 88))
                .tint(.red)
        }
        .padding(.bottom)
    }
}

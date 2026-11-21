import SwiftUI

/// Fills the screen while the phone listens. An item goes to the list when the phone is sure of it, after a pause.
/// Until then, the last row shows what the phone hears, so the speaker sees that it works.
struct DictationScreen: View {
    let dictation: Dictation
    let stop: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            List {
                ForEach(Array(dictation.items.enumerated()), id: \.offset) { _, item in
                    Text(item).font(.title2)
                }
                HStack {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative)
                        .accessibilityHidden(true)
                    Text(dictation.hearing.isEmpty ? String(localized: "Say your items…") : dictation.hearing)
                        .italic()
                }
                .font(.title2)
                .foregroundStyle(.secondary)
            }
            .defaultScrollAnchor(.bottom)
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

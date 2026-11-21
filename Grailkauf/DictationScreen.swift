import SwiftUI

/// Fills the screen while the finger holds the dictation button.
/// A part goes to the list after a pause. A spinner shows while the language model splits it into items.
/// The last row shows what the phone hears now: a moving waveform while words come in, a microphone while it waits.
struct DictationScreen: View {
    let dictation: Dictation
    /// False after the finger lets go, while the last parts become items.
    let holding: Bool

    var body: some View {
        VStack(spacing: 24) {
            List {
                ForEach(Array(dictation.parts.enumerated()), id: \.offset) { _, part in
                    if let items = part.items {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in Text(item) }
                    } else {
                        HStack {
                            Text(part.text).foregroundStyle(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                if holding { hearing }
            }
            .font(.title2)
            .defaultScrollAnchor(.bottom)
            Group {
                if holding {
                    Text("Let go to add the items.")
                } else {
                    Label {
                        Text("Adding the items…")
                    } icon: {
                        ProgressView()
                    }
                }
            }
            .font(.title3)
            .foregroundStyle(.secondary)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        // The finger holds the button below this screen. The screen must not take the touch.
        .allowsHitTesting(false)
    }

    private var hearing: some View {
        HStack {
            if dictation.hearing.isEmpty {
                Image(systemName: "mic").accessibilityHidden(true)
                Text("Say your items…")
            } else {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative)
                    .accessibilityHidden(true)
                Text(dictation.hearing).italic()
            }
        }
        .foregroundStyle(.secondary)
    }
}

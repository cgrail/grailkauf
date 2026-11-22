import SwiftUI

/// Covers the list while the finger holds the dictation button.
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
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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

/// The line above the composer while the finger holds the button: what the app does.
struct RecordingStatus: View {
    let dictation: Dictation

    var body: some View {
        HStack {
            status
            Spacer()
            if dictation.status == .listening, dictation.pending > 0 {
                Label {
                    Text("Splitting…")
                } icon: {
                    ProgressView()
                }
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var status: some View {
        switch dictation.status {
        case .listening: Label("Listening…", systemImage: "ear")
        case .starting: Label { Text("Starting…") } icon: { ProgressView() }
        case .splitting: Label { Text("Splitting…") } icon: { ProgressView() }
        case .adding, nil: Label { Text("Adding…") } icon: { ProgressView() }
        }
    }
}

/// In place of the text field while the finger holds the button: a red waveform of the voice and the time.
struct RecordingBar: View {
    let dictation: Dictation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.caption)
                .symbolEffect(.pulse, isActive: dictation.status == .listening)
                .accessibilityHidden(true)
            waveform
            if let since = dictation.listeningSince {
                Text(since, style: .timer).monospacedDigit()
            }
        }
        .foregroundStyle(.red)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background, in: .capsule)
    }

    /// One bar per moment, newest on the right.
    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(Array(dictation.levels.enumerated()), id: \.offset) { _, level in
                Capsule().frame(width: 3, height: 4 + CGFloat(level) * 24)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .accessibilityHidden(true)
    }
}

/// Sound waves around the held button: the rings grow with the loudness. One ring also pulses in silence.
struct PulseRings: View {
    /// From 0 (silence) to 1.
    let level: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(1...3, id: \.self) { ring in
                Capsule()
                    .stroke(.tint.opacity(0.5 / Double(ring)), lineWidth: 3)
                    .padding(-CGFloat(level) * 10 * CGFloat(ring))
            }
            if !reduceMotion {
                Capsule()
                    .stroke(.tint, lineWidth: 2)
                    .phaseAnimator([false, true]) { ring, out in
                        ring.padding(out ? -28 : 0).opacity(out ? 0 : 0.6)
                    } animation: { out in
                        out ? .easeOut(duration: 1.2) : nil
                    }
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
        .accessibilityHidden(true)
    }
}

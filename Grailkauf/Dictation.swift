import AVFoundation
import GrailkaufCore
import Observation
import Speech

/// Records one spoken list and turns it into items. Speech recognition stays on the phone if the phone can do it.
@MainActor @Observable
final class Dictation {
    /// One stretch of speech up to a pause, and the items in it. `items` is nil while the language model splits it.
    struct Part {
        let text: String
        var items: [String]?
    }

    private(set) var isRecording = false
    /// True once the microphone runs: after the permission prompts.
    private(set) var isListening = false
    /// The parts up to the last pause. The phone is sure of their words.
    private(set) var parts: [Part] = []
    /// What the phone hears since the last pause. It can still change the words.
    private(set) var hearing = ""

    @ObservationIgnored private let recorder = Recorder()
    @ObservationIgnored private var stopping = false
    @ObservationIgnored private var finished = false
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var splitting: [Task<Void, Never>] = []
    @ObservationIgnored private var lastPart = ""

    func start() async throws {
        guard !isRecording else { return }
        // Set at once, so a second press during the permission prompt starts nothing.
        isRecording = true
        parts = []
        splitting = []
        hearing = ""
        lastPart = ""
        finished = false
        do {
            guard await Self.allowed() else { throw Failure.notAllowed }
            // The finger let go during the permission prompt.
            guard isRecording else { return }
            try await recorder.start { [weak self] text, paused, done in
                Task { @MainActor in self?.update(text, paused: paused, done: done) }
            }
            guard isRecording else { return await recorder.stop() }
            isListening = true
        } catch {
            isRecording = false
            throw error
        }
    }

    /// Stops the recording and returns the items, once the language model split the last parts.
    /// Empty if the phone understood nothing, or if the microphone did not run yet.
    func stop() async -> [String] {
        guard isRecording, !stopping else { return [] }
        guard isListening else {
            isRecording = false
            return []
        }
        stopping = true
        await recorder.stop()
        if !finished { await withCheckedContinuation { waiting = $0 } }
        if !hearing.isEmpty { confirm(hearing) }
        hearing = ""
        for task in splitting { await task.value }
        let items = parts.flatMap { $0.items ?? [] }
        stopping = false
        isListening = false
        isRecording = false
        return items
    }

    private func update(_ newText: String?, paused: Bool, done: Bool) {
        // The final result can repeat the part that the last pause ended.
        if let newText, !(paused && newText == lastPart) {
            if paused {
                confirm(newText)
                lastPart = newText
            }
            hearing = paused ? "" : newText
        }
        guard done else { return }
        finished = true
        waiting?.resume()
        waiting = nil
    }

    /// The words of a part are final. The language model splits it now, while the speaker goes on.
    private func confirm(_ text: String) {
        let index = parts.count
        parts.append(Part(text: text))
        splitting.append(Task { parts[index].items = await Self.items(in: text) })
    }

    /// "und", "and" and punctuation split the part, and filler words go away.
    /// With Apple Intelligence, the language model then splits "Milch Sprudel" into two items.
    private static func items(in text: String) async -> [String] {
        var items: [String] = []
        for piece in ItemName.splitSpoken(text) {
            let many = Classifier.isAvailable && piece.split(separator: " ").count > 1
            items += many ? await Classifier.items(in: piece) ?? [piece] : [piece]
        }
        return items
    }

    nonisolated private static func allowed() async -> Bool {
        let speech = await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    enum Failure: LocalizedError {
        case notAllowed, unavailable

        var errorDescription: String? {
            switch self {
            case .notAllowed: String(localized: "Allow the microphone and speech recognition for Grailkauf in Settings.")
            case .unavailable: String(localized: "Speech recognition is not available now. Try again later.")
            }
        }
    }
}

/// The audio part of `Dictation`. It runs off the main thread, because the audio session can block for a while.
private actor Recorder {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// `update` gets the text of the part since the last pause, true at a pause, and true when the recognition is over.
    func start(update: @escaping @Sendable (String?, Bool, Bool) -> Void) throws {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { throw Dictation.Failure.unavailable }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true)
        do {
            try Self.startMicrophone(engine, feeding: request)
        } catch {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
        self.request = request
        task = Self.recognize(request, with: recognizer, update: update)
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // The closures below run on audio and speech threads. They are formed outside the actor,
    // so Swift does not insert an isolation check that stops the app.

    nonisolated private static func startMicrophone(
        _ engine: AVAudioEngine, feeding request: SFSpeechAudioBufferRecognitionRequest
    ) throws {
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    nonisolated private static func recognize(
        _ request: SFSpeechAudioBufferRecognitionRequest, with recognizer: SFSpeechRecognizer,
        update: @escaping @Sendable (String?, Bool, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            // The recognizer adds metadata only to the result that ends a part.
            update(
                result?.bestTranscription.formattedString, result?.speechRecognitionMetadata != nil,
                error != nil || result?.isFinal == true)
        }
    }
}

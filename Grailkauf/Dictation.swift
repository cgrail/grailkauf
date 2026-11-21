import AVFoundation
import FoundationModels
import GrailkaufCore
import Observation
import Speech

/// Records one spoken list and turns it into items. Speech recognition stays on the phone if the phone can do it.
@MainActor @Observable
final class Dictation {
    private(set) var isRecording = false
    /// What the phone understood so far.
    private(set) var text = ""
    /// True once the speaker ends with "fertig" or "done".
    private(set) var heardDone = false
    /// The items so far, split by "und", "and" and punctuation. The language model splits them better at the end.
    var items: [String] { ItemName.splitSpoken(spoken) }
    private var spoken: String { ItemName.beforeDoneWord(text) ?? text }

    @ObservationIgnored private let recorder = Recorder()
    @ObservationIgnored private var stopping = false
    @ObservationIgnored private var finished = false
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?

    func start() async throws {
        guard !isRecording else { return }
        // Set at once, so a second tap during the permission prompt starts nothing.
        isRecording = true
        text = ""
        heardDone = false
        finished = false
        do {
            guard await Self.allowed() else { throw Failure.notAllowed }
            try await recorder.start { [weak self] text, done in
                Task { @MainActor in self?.update(text, done: done) }
            }
        } catch {
            isRecording = false
            throw error
        }
    }

    /// Stops the recording and returns the items. Empty if the phone understood nothing.
    func stop() async -> [String] {
        guard isRecording, !stopping else { return [] }
        stopping = true
        await recorder.stop()
        if !finished { await withCheckedContinuation { waiting = $0 } }
        let items = await Self.items(in: spoken)
        stopping = false
        isRecording = false
        return items
    }

    private func update(_ newText: String?, done: Bool) {
        if let newText {
            text = newText
            if ItemName.beforeDoneWord(newText) != nil { heardDone = true }
        }
        guard done else { return }
        finished = true
        waiting?.resume()
        waiting = nil
    }

    nonisolated private static func allowed() async -> Bool {
        let speech = await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Spoken lists rarely have commas: "zwei Liter Milch Eier Butter". The language model finds the items.
    /// Without the model, "und", "and" and the punctuation of the recognizer split the text.
    private static func items(in text: String) async -> [String] {
        let fallback = ItemName.splitSpoken(text)
        guard Classifier.isAvailable, !fallback.isEmpty else { return fallback }
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(samplingMode: .greedy)
        let answer = try? await session.respond(to: text, generating: SpokenList.self, options: options).content
        let items = (answer?.items ?? []).flatMap(ItemName.split)
        return items.isEmpty ? fallback : items
    }

    private static let instructions = """
        You split a spoken grocery shopping list, in German or English, into its items.
        Keep each item as spoken, with its amount: "zwei Liter Milch". Do not translate, correct or add items.
        """

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

@Generable
struct SpokenList {
    @Guide(description: "The items in the order spoken")
    var items: [String]
}

/// The audio part of `Dictation`. It runs off the main thread, because the audio session can block for a while.
private actor Recorder {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// `update` gets the text so far, and true when the recognition is over.
    func start(update: @escaping @Sendable (String?, Bool) -> Void) throws {
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
        update: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            update(result?.bestTranscription.formattedString, error != nil || result?.isFinal == true)
        }
    }
}

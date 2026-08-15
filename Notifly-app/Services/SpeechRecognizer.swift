import Foundation
import Speech
import AVFoundation

/// Errors raised while setting up capture, with messages suitable for showing
/// directly to a clinician in the UI.
enum SpeechCaptureError: LocalizedError {
    case microphoneAccessDenied
    case noCompatibleAudioFormat

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is off. Enable it in Settings > NOTIFLY, then try again."
        case .noCompatibleAudioFormat:
            return "This device can't supply audio in a format the on-device transcriber accepts."
        }
    }
}

/// Converts mic buffers into the format the analyzer asked for.
///
/// Only ever touched from the audio tap, which calls back on one serial
/// real-time thread — hence the unchecked conformance rather than actor
/// isolation, which would force a hop on the audio path.
private final class BufferConverter: @unchecked Sendable {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format != format else { return buffer }

        if converter?.inputFormat != buffer.format || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            // Priming injects leading silence the transcriber would have to
            // chew through on every buffer.
            converter?.primeMethod = .none
        }
        guard let converter else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard capacity > 0,
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }

        guard error == nil, output.frameLength > 0 else { return nil }
        return output
    }
}

@Observable
@MainActor
class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var isPaused = false
    var isTranscribing = false
    var transcribingProgress: String = ""
    var errorMessage: String?
    /// Normalised mic input level (0...1) updated while recording.
    var inputLevel: Float = 0

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// Text the transcriber has committed to, kept apart from the in-progress
    /// guess that replaces itself as the clinician keeps talking — so a
    /// volatile tail can be swapped out without disturbing settled text.
    private var finalizedText = ""
    private var volatileText = ""

    /// Common allied-health vocabulary used to bias the on-device transcriber
    /// toward terms it would otherwise mishear.
    private static let clinicalContextualStrings: [String] = [
        "occupational therapy", "physiotherapy", "speech pathology",
        "pincer grasp", "tripod grasp", "palmar grasp",
        "fine motor", "gross motor", "bilateral coordination",
        "proprioceptive", "vestibular", "tactile defensiveness",
        "sensory processing", "sensory integration", "self-regulation",
        "range of motion", "activities of daily living", "ADLs",
        "hand-over-hand", "hand dominance", "joint play",
        "minimum assist", "moderate assist", "maximum assist", "modified independent",
        "sitting tolerance", "social engagement", "executive function",
        "dyspraxia", "apraxia", "praxis", "motor planning"
    ]

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Streams the mic straight into the analyzer, so the transcript builds up
    /// during the session instead of being produced from a recorded file after
    /// it. Nothing is written to disk.
    func startRecording() async throws {
        transcript = ""
        finalizedText = ""
        volatileText = ""
        errorMessage = nil
        transcribingProgress = ""
        inputLevel = 0

        guard await AVAudioApplication.requestRecordPermission() else {
            throw SpeechCaptureError.microphoneAccessDenied
        }

        // Model setup can stall on a first-run asset download, so it reports
        // progress and blocks the record button the same way transcription did.
        isTranscribing = true
        transcribingProgress = "Preparing speech model..."
        defer {
            isTranscribing = false
            transcribingProgress = ""
        }

        // Setup fails as a unit: a half-built session left behind would other-
        // wise still be feeding the analyzer when the clinician taps retry.
        do {
            try await beginStreaming()
        } catch {
            teardown()
            throw error
        }

        isRecording = true
        isPaused = false
    }

    private func beginStreaming() async throws {
        // Use the device's locale if supported, otherwise fall back to en_US.
        // SpeechTranscriber.supportedLocale handles regional variants for us.
        let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
            ?? Locale(identifier: "en_US")

        // .volatileResults is what puts words on screen as they are spoken;
        // without it results only arrive once a phrase is finalised.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        if let installRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installRequest.downloadAndInstall()
        }

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechCaptureError.noCompatibleAudioFormat
        }

        // Bias the analyzer toward clinical vocabulary.
        let context = AnalysisContext()
        context.contextualStrings = [.general: Self.clinicalContextualStrings]

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.setContext(context)
        self.analyzer = analyzer

        let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        collectResults(from: transcriber)

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        installTap(convertingTo: analyzerFormat, into: continuation)

        try await analyzer.start(inputSequence: inputSequence)

        audioEngine.prepare()
        try audioEngine.start()

        print("[SpeechRecognizer] Streaming to analyzer (locale: \(locale.identifier))")
    }

    /// Drops everything the streaming session owns. Safe to call more than once,
    /// and safe to call on a session that was only partly built.
    private func teardown() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        inputContinuation?.finish()
        inputContinuation = nil

        resultsTask?.cancel()
        resultsTask = nil

        analyzer = nil
        transcriber = nil

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        // Pausing the engine stops the tap being called, so no audio reaches
        // the analyzer until resume — the session itself stays open.
        audioEngine.pause()
        isPaused = true
        inputLevel = 0
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        do {
            try audioEngine.start()
            isPaused = false
        } catch {
            errorMessage = "Couldn't resume recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard isRecording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        isPaused = false
        inputLevel = 0

        // Only the tail of the session is still outstanding — everything before
        // it was transcribed while it was being spoken.
        isTranscribing = true
        transcribingProgress = "Finishing transcription..."

        inputContinuation?.finish()
        inputContinuation = nil

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value

        // Anything still volatile was never committed by the transcriber —
        // drop it rather than let an unconfirmed guess into the note's source.
        volatileText = ""
        transcript = finalizedText

        isTranscribing = false
        transcribingProgress = ""

        teardown()

        print("[SpeechRecognizer] Transcription complete: \(transcript.count) chars")

        if transcript.isEmpty, errorMessage == nil {
            errorMessage = "Transcription produced no text. The recording may be too quiet or unclear."
        }
    }

    private func collectResults(from transcriber: SpeechTranscriber) {
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    self?.apply(text: String(result.text.characters), isFinal: result.isFinal)
                }
            } catch {
                self?.errorMessage = "Transcription failed: \(error.localizedDescription)"
                print("[SpeechRecognizer] Error: \(error)")
            }
        }
    }

    /// A final result appends to the settled text; a volatile one replaces the
    /// current guess, which the transcriber revises as more audio arrives.
    private func apply(text: String, isFinal: Bool) {
        if isFinal {
            finalizedText += text
            volatileText = ""
        } else {
            volatileText = text
        }
        transcript = finalizedText + volatileText
    }

    private func installTap(convertingTo format: AVAudioFormat, into continuation: AsyncStream<AnalyzerInput>.Continuation) {
        let inputNode = audioEngine.inputNode
        let converter = BufferConverter()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            let level = Self.normalisedLevel(of: buffer)
            Task { @MainActor in
                self?.inputLevel = level
            }

            guard let converted = converter.convert(buffer, to: format) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
    }

    /// RMS mapped to 0...1 on the same -50 dB floor the old metering used, so
    /// the recording orb keeps its existing feel.
    private nonisolated static func normalisedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        var sumOfSquares: Float = 0
        for frame in 0..<frames {
            let sample = channel[frame]
            sumOfSquares += sample * sample
        }

        let rms = sqrt(sumOfSquares / Float(frames))
        guard rms > 0 else { return 0 }

        let minDB: Float = -50
        let clamped = max(min(20 * log10(rms), 0), minDB)
        return (clamped - minDB) / -minDB
    }
}

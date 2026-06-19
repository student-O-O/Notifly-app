import Foundation
import Speech
import AVFoundation

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

    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?
    private var levelTask: Task<Void, Never>?

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

    func startRecording() throws {
        transcript = ""
        errorMessage = nil
        transcribingProgress = ""
        inputLevel = 0

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notifly-recording-\(UUID().uuidString).wav")
        audioURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            errorMessage = "Failed to start recording. Please check microphone permissions."
            audioURL = nil
            return
        }
        audioRecorder = recorder
        isRecording = true
        isPaused = false
        startLevelMonitoring()
        print("[SpeechRecognizer] Recording to \(url.lastPathComponent)")
    }

    func pauseRecording() {
        guard isRecording, !isPaused, let recorder = audioRecorder else { return }
        recorder.pause()
        isPaused = true
        stopLevelMonitoring()
        inputLevel = 0
    }

    func resumeRecording() {
        guard isRecording, isPaused, let recorder = audioRecorder else { return }
        if recorder.record() {
            isPaused = false
            startLevelMonitoring()
        }
    }

    func stopRecording() async {
        guard isRecording, let recorder = audioRecorder, let url = audioURL else {
            isRecording = false
            stopLevelMonitoring()
            return
        }

        stopLevelMonitoring()
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        isPaused = false
        inputLevel = 0
        print("[SpeechRecognizer] Recording stopped. Starting transcription...")

        isTranscribing = true
        await transcribe(url: url)
        isTranscribing = false
        transcribingProgress = ""

        try? FileManager.default.removeItem(at: url)
        audioURL = nil
    }

    private func startLevelMonitoring() {
        levelTask?.cancel()
        levelTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let recorder = self.audioRecorder, recorder.isRecording {
                    recorder.updateMeters()
                    let dB = recorder.averagePower(forChannel: 0)
                    // dB is typically -160 (silent) to 0 (max). Map to 0...1.
                    let minDB: Float = -50
                    let clamped = max(min(dB, 0), minDB)
                    let normalised = (clamped - minDB) / -minDB
                    self.inputLevel = normalised
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTask?.cancel()
        levelTask = nil
    }

    private func transcribe(url: URL) async {
        do {
            transcribingProgress = "Preparing transcription..."

            // Use the device's locale if supported, otherwise fall back to en_US.
            // SpeechTranscriber.supportedLocale handles regional variants for us.
            let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
                ?? Locale(identifier: "en_US")

            let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

            if let installRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                transcribingProgress = "Preparing speech model..."
                try await installRequest.downloadAndInstall()
            }

            transcribingProgress = "Transcribing recording..."

            // Bias the analyzer toward clinical vocabulary. Contextual strings
            // are most effective with DictationTranscriber but setting them here
            // is harmless and supports any module that consults them.
            let context = AnalysisContext()
            context.contextualStrings = [.general: Self.clinicalContextualStrings]

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            try await analyzer.setContext(context)

            let audioFile = try AVAudioFile(forReading: url)

            async let collectedTask: String = {
                var text = ""
                for try await result in transcriber.results where result.isFinal {
                    text += String(result.text.characters)
                }
                return text
            }()

            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

            let collected = try await collectedTask
            transcript = collected
            print("[SpeechRecognizer] Transcription complete: \(transcript.count) chars (locale: \(locale.identifier))")

            if transcript.isEmpty {
                errorMessage = "Transcription produced no text. The recording may be too quiet or unclear."
            }
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            print("[SpeechRecognizer] Error: \(error)")
        }
    }
}

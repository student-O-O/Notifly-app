import Foundation
import Speech
import AVFoundation

@Observable
@MainActor
class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var isTranscribing = false
    var transcribingProgress: String = ""
    var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?

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

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .spokenAudio, options: .duckOthers)
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
        guard recorder.record() else {
            errorMessage = "Failed to start recording. Please check microphone permissions."
            audioURL = nil
            return
        }
        audioRecorder = recorder
        isRecording = true
        print("[SpeechRecognizer] Recording to \(url.lastPathComponent)")
    }

    func stopRecording() async {
        guard isRecording, let recorder = audioRecorder, let url = audioURL else {
            isRecording = false
            return
        }

        recorder.stop()
        audioRecorder = nil
        isRecording = false
        print("[SpeechRecognizer] Recording stopped. Starting transcription...")

        isTranscribing = true
        await transcribe(url: url)
        isTranscribing = false
        transcribingProgress = ""

        try? FileManager.default.removeItem(at: url)
        audioURL = nil
    }

    private func transcribe(url: URL) async {
        do {
            transcribingProgress = "Preparing transcription..."

            let transcriber = SpeechTranscriber(
                locale: Locale.current,
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: []
            )

            // Ensure the on-device speech model is installed for this locale
            if let installRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                transcribingProgress = "Preparing speech model..."
                try await installRequest.downloadAndInstall()
            }

            transcribingProgress = "Transcribing recording..."

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let audioFile = try AVAudioFile(forReading: url)

            // Collect results concurrently so the stream is drained while the
            // analyzer is still feeding it.
            async let collectedTask: String = {
                var text = ""
                for try await result in transcriber.results where result.isFinal {
                    text += String(result.text.characters)
                }
                return text
            }()

            // `finishAfterFile: true` tells the analyzer this file is the entire
            // input — without it, the analyzer waits for more audio and the
            // results stream never terminates.
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

            let collected = try await collectedTask
            transcript = collected
            print("[SpeechRecognizer] Transcription complete: \(transcript.count) chars")

            if transcript.isEmpty {
                errorMessage = "Transcription produced no text. The recording may be too quiet or unclear."
            }
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            print("[SpeechRecognizer] Error: \(error)")
        }
    }
}

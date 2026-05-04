import Foundation
import Speech
import AVFoundation

@Observable
@MainActor
class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private var segments: [String] = []
    private var currentSegmentText = ""
    private var taskGeneration = 0

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording() throws {
        stopRecording()
        transcript = ""
        segments = []
        currentSegmentText = ""
        errorMessage = nil

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            errorMessage = "No microphone available. Please check microphone permissions in System Settings > Privacy & Security > Microphone."
            audioEngine = nil
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        beginRecognitionTask()
    }

    private func commitCurrentSegment() {
        if !currentSegmentText.isEmpty {
            segments.append(currentSegmentText)
            print("[SpeechRecognizer] Committed segment \(segments.count): \(currentSegmentText.prefix(80))... (\(currentSegmentText.count) chars)")
            currentSegmentText = ""
        }
        rebuildTranscript()
    }

    private func rebuildTranscript() {
        if currentSegmentText.isEmpty {
            transcript = segments.joined(separator: " ")
        } else if segments.isEmpty {
            transcript = currentSegmentText
        } else {
            transcript = segments.joined(separator: " ") + " " + currentSegmentText
        }
    }

    private func beginRecognitionTask() {
        commitCurrentSegment()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        taskGeneration += 1
        let currentGeneration = taskGeneration

        guard let speechRecognizer, speechRecognizer.isAvailable, isRecording else {
            if isRecording {
                print("[SpeechRecognizer] Recognizer unavailable, retrying in 2s...")
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard self.isRecording, self.taskGeneration == currentGeneration else { return }
                    self.beginRecognitionTask()
                }
            }
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation

        #if os(iOS)
        request.requiresOnDeviceRecognition = true
        #endif

        recognitionRequest = request

        print("[SpeechRecognizer] Starting recognition task (gen \(currentGeneration)), \(segments.count) segments saved so far")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.isRecording, self.taskGeneration == currentGeneration else { return }

                if let result {
                    let newText = result.bestTranscription.formattedString

                    // Detect recognizer internal reset: if the new text is dramatically
                    // shorter than what we had, the recognizer discarded its buffer and
                    // started fresh. Commit the old text before it's lost.
                    if self.currentSegmentText.count > 50 &&
                       newText.count < self.currentSegmentText.count / 2 {
                        print("[SpeechRecognizer] Internal reset detected: \(self.currentSegmentText.count) → \(newText.count) chars. Saving segment.")
                        self.segments.append(self.currentSegmentText)
                        self.currentSegmentText = ""
                    }

                    self.currentSegmentText = newText
                    self.rebuildTranscript()

                    if result.isFinal {
                        print("[SpeechRecognizer] isFinal received (\(newText.count) chars)")
                        self.commitCurrentSegment()
                        self.beginRecognitionTask()
                    }
                } else if error != nil {
                    print("[SpeechRecognizer] Error: \(error!.localizedDescription)")
                    self.commitCurrentSegment()
                    self.beginRecognitionTask()
                }
            }
        }
    }

    func stopRecording() {
        isRecording = false
        taskGeneration += 1
        commitCurrentSegment()
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        print("[SpeechRecognizer] Stopped. Total segments: \(segments.count), transcript length: \(transcript.count)")
    }
}

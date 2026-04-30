import Foundation
import Speech
import AVFoundation

@Observable
@MainActor
class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private var finalizedTranscript = ""

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
        finalizedTranscript = ""
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        startRecognitionTask()
    }

    private func startRecognitionTask() {
        guard let speechRecognizer, speechRecognizer.isAvailable, isRecording else { return }

        recognitionRequest?.endAudio()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.isRecording else { return }

                if let result {
                    let currentText = result.bestTranscription.formattedString
                    if self.finalizedTranscript.isEmpty {
                        self.transcript = currentText
                    } else {
                        self.transcript = self.finalizedTranscript + " " + currentText
                    }

                    if result.isFinal {
                        self.finalizedTranscript = self.transcript
                        self.startRecognitionTask()
                    }
                } else if error != nil {
                    self.finalizedTranscript = self.transcript
                    self.startRecognitionTask()
                }
            }
        }
    }

    func stopRecording() {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}

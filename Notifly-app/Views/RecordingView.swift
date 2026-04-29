import SwiftUI
import FoundationModels

struct RecordingView: View {
    let clientInitials: String
    let noteFormat: NoteFormat
    var onComplete: () -> Void

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isAuthorized = false
    @State private var showReview = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            if !isAuthorized {
                authorizationView
            } else {
                recordingContent
            }
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(speechRecognizer.isRecording)
        .task {
            isAuthorized = await SpeechRecognizer.requestAuthorization()
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewNoteView(
                clientInitials: clientInitials,
                noteFormat: noteFormat,
                transcript: speechRecognizer.transcript,
                onComplete: onComplete
            )
        }
    }

    private var authorizationView: some View {
        ContentUnavailableView {
            Label("Microphone Access Required", systemImage: "mic.slash")
        } description: {
            Text("Please enable Speech Recognition and Microphone access in Settings to use this feature.")
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 24) {
            ScrollView {
                Text(speechRecognizer.transcript.isEmpty ? "Tap the microphone to begin recording..." : speechRecognizer.transcript)
                    .foregroundStyle(speechRecognizer.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: .infinity)

            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                Text(formattedTime)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.secondary)

                recordButton

                if !speechRecognizer.isRecording && !speechRecognizer.transcript.isEmpty {
                    Button {
                        showReview = true
                    } label: {
                        Label("Continue to Review", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var recordButton: some View {
        Button {
            if speechRecognizer.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(speechRecognizer.isRecording ? .red : .accentColor)
                    .frame(width: 80, height: 80)

                Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel(speechRecognizer.isRecording ? "Stop Recording" : "Start Recording")
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startRecording() {
        do {
            try speechRecognizer.startRecording()
            elapsedSeconds = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds += 1
            }
        } catch {
            speechRecognizer.errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        speechRecognizer.stopRecording()
        timer?.invalidate()
        timer = nil
    }
}

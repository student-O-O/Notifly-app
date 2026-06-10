import SwiftUI
import FoundationModels

struct RecordingView: View {
    let clientInitials: String
    let noteFormat: NoteFormat
    var tone: NoteTone = .standard
    var onComplete: () -> Void

    let sessionID = UUID()
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(speechRecognizer.isRecording || speechRecognizer.isTranscribing)
        #endif
        .task {
            isAuthorized = await SpeechRecognizer.requestAuthorization()
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewNoteView(
                clientInitials: clientInitials,
                noteFormat: noteFormat,
                tone: tone,
                sessionID: sessionID,
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
                if speechRecognizer.isTranscribing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(speechRecognizer.transcribingProgress.isEmpty ? "Transcribing recording..." : speechRecognizer.transcribingProgress)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    Text(promptText)
                        .foregroundStyle(speechRecognizer.transcript.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(maxHeight: .infinity)

            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                if speechRecognizer.isRecording {
                    levelMeter
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }

                Text(formattedTime)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.secondary)

                recordButton

                if !speechRecognizer.isRecording && !speechRecognizer.isTranscribing && !speechRecognizer.transcript.isEmpty {
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

    private var promptText: String {
        if speechRecognizer.isRecording {
            return "Recording... Tap stop when finished."
        }
        if speechRecognizer.transcript.isEmpty {
            return "Tap the microphone to begin recording..."
        }
        return speechRecognizer.transcript
    }

    private var recordButton: some View {
        Button {
            if speechRecognizer.isRecording {
                Task { await stopRecording() }
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                // Outer pulsing ring that scales with mic input level while recording
                if speechRecognizer.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .scaleEffect(1.0 + CGFloat(speechRecognizer.inputLevel) * 0.6)
                        .opacity(0.6 + Double(speechRecognizer.inputLevel) * 0.4)
                        .animation(.easeOut(duration: 0.12), value: speechRecognizer.inputLevel)
                }

                Circle()
                    .fill(speechRecognizer.isRecording ? .red : .accentColor)
                    .frame(width: 80, height: 80)

                Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
        }
        .disabled(speechRecognizer.isTranscribing)
        .opacity(speechRecognizer.isTranscribing ? 0.4 : 1.0)
        .accessibilityLabel(speechRecognizer.isRecording ? "Stop Recording" : "Start Recording")
    }

    @ViewBuilder
    private var levelMeter: some View {
        HStack(spacing: 3) {
            ForEach(0..<14, id: \.self) { i in
                let threshold = Float(i) / 14.0
                Capsule()
                    .fill(speechRecognizer.inputLevel > threshold ? Color.red.opacity(0.85) : Color.gray.opacity(0.25))
                    .frame(width: 4, height: 16 + CGFloat(i) * 1.5)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.08), value: speechRecognizer.inputLevel)
        .accessibilityLabel("Microphone input level")
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

    private func stopRecording() async {
        timer?.invalidate()
        timer = nil
        await speechRecognizer.stopRecording()
    }
}

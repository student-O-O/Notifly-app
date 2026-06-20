import SwiftUI
import FoundationModels

struct RecordingView: View {
    let client: Client
    let noteFormat: NoteFormat
    var tone: NoteTone = .standard
    @Binding var dismissSheet: Bool

    let sessionID = UUID()
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isAuthorized = false
    @State private var showReview = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?
    @State private var didAutoStart = false

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
            if isAuthorized && !didAutoStart {
                didAutoStart = true
                startRecording()
            }
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewNoteView(
                clientName: client.displayName,
                client: client,
                noteFormat: noteFormat,
                tone: tone,
                sessionID: sessionID,
                transcript: speechRecognizer.transcript,
                dismissSheet: $dismissSheet
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

            VStack(spacing: 24) {
                Text(formattedTime)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.secondary)

                recordButton
                    .frame(width: 220, height: 220)

                if speechRecognizer.isRecording {
                    Button {
                        Task {
                            await stopRecording()
                            if !speechRecognizer.transcript.isEmpty {
                                showReview = true
                            }
                        }
                    } label: {
                        Label("Generate Note", systemImage: "sparkles")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                } else if !speechRecognizer.isTranscribing && !speechRecognizer.transcript.isEmpty {
                    Button {
                        showReview = true
                    } label: {
                        Label("Generate Note", systemImage: "sparkles")
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
            if speechRecognizer.isPaused {
                return "Paused. Tap the orb to resume, or Generate Note to finish."
            }
            return "Recording... Tap the orb to pause, or Generate Note when finished."
        }
        if speechRecognizer.transcript.isEmpty {
            return "Preparing microphone..."
        }
        return speechRecognizer.transcript
    }

    private var recordButton: some View {
        Button {
            if speechRecognizer.isRecording {
                if speechRecognizer.isPaused {
                    speechRecognizer.resumeRecording()
                    startTimer()
                } else {
                    speechRecognizer.pauseRecording()
                    pauseTimer()
                }
            } else {
                startRecording()
            }
        } label: {
            if speechRecognizer.isRecording {
                siriOrb
            } else {
                idleMicButton
            }
        }
        .buttonStyle(.plain)
        .disabled(speechRecognizer.isTranscribing)
        .opacity(speechRecognizer.isTranscribing ? 0.4 : 1.0)
        .accessibilityLabel(recordButtonAccessibilityLabel)
    }

    private var recordButtonAccessibilityLabel: String {
        if !speechRecognizer.isRecording { return "Start Recording" }
        return speechRecognizer.isPaused ? "Resume Recording" : "Pause Recording"
    }

    private var idleMicButton: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.gradient)
                .frame(width: 90, height: 90)
                .shadow(color: .accentColor.opacity(0.4), radius: 14, y: 4)

            Image(systemName: "mic.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var siriOrb: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let level = CGFloat(speechRecognizer.inputLevel)
            let breath = sin(t * 1.6) * 0.5 + 0.5
            let paused = speechRecognizer.isPaused

            ZStack {
                // Soft outer aura — breathes slowly, swells with audio
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .pink.opacity(0.55),
                                .red.opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(0.85 + level * 0.35 + breath * 0.06)
                    .opacity(0.55 + Double(level) * 0.45)
                    .blur(radius: 20)

                // Rotating angular gradient ring — gives the orb its "Siri" colour life
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .pink, .red, .orange, .pink, .purple],
                            center: .center
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(1.0 + level * 0.22 + breath * 0.03)
                    .rotationEffect(.degrees(t * 28))
                    .blur(radius: 14)
                    .opacity(0.85)

                // Inner glossy core — the actual tap target visual
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .red.opacity(0.55), radius: 12, y: 3)
                    .scaleEffect(1.0 + level * 0.06)

                // Glyph: pause when recording, play when paused
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .opacity(paused ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: speechRecognizer.inputLevel)
            .animation(.easeInOut(duration: 0.2), value: paused)
        }
        .accessibilityLabel(speechRecognizer.isPaused ? "Resume Recording" : "Pause Recording")
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
            startTimer()
        } catch {
            speechRecognizer.errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopRecording() async {
        pauseTimer()
        await speechRecognizer.stopRecording()
    }
}

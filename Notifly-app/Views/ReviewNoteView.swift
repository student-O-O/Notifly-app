import SwiftUI
import SwiftData
import FoundationModels

struct ReviewNoteView: View {
    let clientInitials: String
    let noteFormat: NoteFormat
    let transcript: String
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isGenerating = true
    @State private var generationError: String?

    @State private var subjective = ""
    @State private var objective = ""
    @State private var assessment = ""
    @State private var plan = ""
    @State private var data = ""
    @State private var goalsAddressed = ""
    @State private var timeSpent = ""
    @State private var interventionsUsed = ""

    @State private var showTranscript = false
    @State private var saved = false

    var body: some View {
        Group {
            if isGenerating {
                generatingView
            } else if let error = generationError {
                errorView(error)
            } else {
                noteForm
            }
        }
        .navigationTitle("Review Note")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(saved)
        .task {
            await generateNote()
        }
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Generating your \(noteFormat.rawValue) note...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Generation Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") {
                generationError = nil
                isGenerating = true
                Task { await generateNote() }
            }
        }
    }

    private var noteForm: some View {
        Form {
            Section {
                DisclosureGroup("Transcript", isExpanded: $showTranscript) {
                    Text(transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            switch noteFormat {
            case .soap:
                soapFields
            case .dap:
                dapFields
            }

            commonFields

            Section {
                Button {
                    saveNote()
                } label: {
                    Label("Save Note", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .disabled(saved)
            }
        }
    }

    private var soapFields: some View {
        Group {
            Section("Subjective") {
                TextEditor(text: $subjective)
                    .frame(minHeight: 80)
            }
            Section("Objective") {
                TextEditor(text: $objective)
                    .frame(minHeight: 80)
            }
            Section("Assessment") {
                TextEditor(text: $assessment)
                    .frame(minHeight: 80)
            }
            Section("Plan") {
                TextEditor(text: $plan)
                    .frame(minHeight: 80)
            }
        }
    }

    private var dapFields: some View {
        Group {
            Section("Data") {
                TextEditor(text: $data)
                    .frame(minHeight: 80)
            }
            Section("Assessment") {
                TextEditor(text: $assessment)
                    .frame(minHeight: 80)
            }
            Section("Plan") {
                TextEditor(text: $plan)
                    .frame(minHeight: 80)
            }
        }
    }

    private var commonFields: some View {
        Group {
            Section("Goals Addressed") {
                TextEditor(text: $goalsAddressed)
                    .frame(minHeight: 60)
            }
            Section("Time Spent") {
                TextEditor(text: $timeSpent)
                    .frame(minHeight: 40)
            }
            Section("Interventions Used") {
                TextEditor(text: $interventionsUsed)
                    .frame(minHeight: 60)
            }
        }
    }

    private func generateNote() async {
        do {
            switch noteFormat {
            case .soap:
                let note = try await NoteGenerationService.generateSOAP(transcript: transcript)
                subjective = note.subjective
                objective = note.objective
                assessment = note.assessment
                plan = note.plan
                goalsAddressed = note.goalsAddressed
                timeSpent = note.timeSpent
                interventionsUsed = note.interventionsUsed
            case .dap:
                let note = try await NoteGenerationService.generateDAP(transcript: transcript)
                data = note.data
                assessment = note.assessment
                plan = note.plan
                goalsAddressed = note.goalsAddressed
                timeSpent = note.timeSpent
                interventionsUsed = note.interventionsUsed
            }
            isGenerating = false
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }

    private func saveNote() {
        let note = SessionNote(
            clientInitials: clientInitials,
            noteFormat: noteFormat,
            transcript: transcript,
            subjective: subjective,
            objective: objective,
            assessment: assessment,
            plan: plan,
            data: data,
            goalsAddressed: goalsAddressed,
            timeSpent: timeSpent,
            interventionsUsed: interventionsUsed
        )
        modelContext.insert(note)
        saved = true
        onComplete()
    }
}

import SwiftUI
import SwiftData
import FoundationModels

struct ReviewNoteView: View {
    let clientInitials: String
    let noteFormat: NoteFormat
    var tone: NoteTone = .standard
    let sessionID: UUID
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

    @State private var sessionObservations = ""
    @State private var goalCards: [GoalCard] = []

    @State private var showTranscript = false
    @State private var saved = false
    @State private var selectedTone: NoteTone?
    @State private var showRegenerateSheet = false
    @State private var navigateToRegenerated = false
    @State private var regenerateTone: NoteTone = .standard

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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(saved)
        #endif
        .task {
            if selectedTone == nil {
                selectedTone = tone
            }
            await generateNote()
        }
        .sheet(isPresented: $showRegenerateSheet) {
            regenerateSheet
        }
        .navigationDestination(isPresented: $navigateToRegenerated) {
            ReviewNoteView(
                clientInitials: clientInitials,
                noteFormat: noteFormat,
                tone: regenerateTone,
                sessionID: sessionID,
                transcript: transcript,
                onComplete: onComplete
            )
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
                LabeledContent("Tone", value: (selectedTone ?? tone).rawValue)
            }

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
                commonFields
            case .dap:
                dapFields
                commonFields
            case .goalFocused:
                goalFocusedFields
            }

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

            if saved {
                Section {
                    Button {
                        regenerateTone = selectedTone ?? tone
                        showRegenerateSheet = true
                    } label: {
                        Label("Generate Another Note", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                }
            }
        }
    }

    private var regenerateSheet: some View {
        NavigationStack {
            Form {
                Section("Select Tone") {
                    Picker("Tone", selection: $regenerateTone) {
                        ForEach(NoteTone.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(regenerateTone.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showRegenerateSheet = false
                        navigateToRegenerated = true
                    } label: {
                        Label("Generate Note", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Generate Another Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRegenerateSheet = false }
                }
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

    @ViewBuilder
    private var goalFocusedFields: some View {
        Section("Session Observations") {
            TextEditor(text: $sessionObservations)
                .frame(minHeight: 60)
        }

        ForEach(goalCards.indices, id: \.self) { index in
            Section {
                TextField("Goal", text: Binding(
                    get: { goalCards[index].goal },
                    set: { goalCards[index].goal = $0 }
                ), axis: .vertical)
                    .font(.headline)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Activities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { goalCards[index].activities },
                        set: { goalCards[index].activities = $0 }
                    ))
                    .frame(minHeight: 60)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Observations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { goalCards[index].observations },
                        set: { goalCards[index].observations = $0 }
                    ))
                    .frame(minHeight: 60)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { goalCards[index].nextSteps },
                        set: { goalCards[index].nextSteps = $0 }
                    ))
                    .frame(minHeight: 60)
                }
            } header: {
                Text(goalCards.count > 1 ? "Goal \(index + 1)" : "Goal")
            }
        }

        Section {
            Button {
                goalCards.append(GoalCard(goal: "", activities: "", observations: "", nextSteps: ""))
            } label: {
                Label("Add Goal", systemImage: "plus.circle")
            }

            if !goalCards.isEmpty {
                Button(role: .destructive) {
                    goalCards.removeLast()
                } label: {
                    Label("Remove Last Goal", systemImage: "minus.circle")
                }
            }
        }
    }

    private func generateNote() async {
        let currentTone = selectedTone ?? tone
        do {
            switch noteFormat {
            case .soap:
                let note = try await NoteGenerationService.generateSOAP(transcript: transcript, tone: currentTone)
                subjective = note.subjective
                objective = note.objective
                assessment = note.assessment
                plan = note.plan
                goalsAddressed = note.goalsAddressed
                timeSpent = note.timeSpent
                interventionsUsed = note.interventionsUsed
            case .dap:
                let note = try await NoteGenerationService.generateDAP(transcript: transcript, tone: currentTone)
                data = note.data
                assessment = note.assessment
                plan = note.plan
                goalsAddressed = note.goalsAddressed
                timeSpent = note.timeSpent
                interventionsUsed = note.interventionsUsed
            case .goalFocused:
                let note = try await NoteGenerationService.generateGoalFocused(transcript: transcript, tone: currentTone)
                sessionObservations = note.sessionObservations
                goalCards = note.goals.map {
                    GoalCard(goal: $0.goal, activities: $0.activities, observations: $0.observations, nextSteps: $0.nextSteps)
                }
            }
            isGenerating = false
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }

    private func saveNote() {
        let currentTone = selectedTone ?? tone
        let note = SessionNote(
            clientInitials: clientInitials,
            noteFormat: noteFormat,
            tone: currentTone,
            sessionID: sessionID,
            transcript: transcript,
            subjective: subjective,
            objective: objective,
            assessment: assessment,
            plan: plan,
            data: data,
            goalsAddressed: goalsAddressed,
            timeSpent: timeSpent,
            interventionsUsed: interventionsUsed,
            sessionObservations: sessionObservations,
            goalCards: goalCards
        )
        modelContext.insert(note)
        saved = true
    }
}

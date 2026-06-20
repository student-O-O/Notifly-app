import SwiftUI
import SwiftData
import FoundationModels

struct ReviewNoteView: View {
    let clientName: String
    var client: Client?
    let noteFormat: NoteFormat
    var tone: NoteTone = .standard
    let sessionID: UUID
    let transcript: String
    @Binding var dismissSheet: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var isGenerating = true
    @State private var generationError: String?
    @State private var insufficientContentReason: String?

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
    @State private var regenerateFormat: NoteFormat = .soap

    var body: some View {
        Group {
            if isGenerating {
                generatingView
            } else if let error = generationError {
                errorView(error)
            } else if let reason = insufficientContentReason {
                insufficientView(reason)
            } else {
                noteForm
            }
        }
        .overlay {
            if isGenerating {
                intelligenceHalo
            }
        }
        .navigationTitle("Review Note")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
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
                clientName: clientName,
                client: client,
                noteFormat: regenerateFormat,
                tone: regenerateTone,
                sessionID: sessionID,
                transcript: transcript,
                dismissSheet: $dismissSheet
            )
        }
    }

    private static let intelligenceColors: [Color] = [
        Color(red: 0.42, green: 0.20, blue: 0.95),  // deep purple
        Color(red: 0.85, green: 0.25, blue: 0.80),  // magenta
        Color(red: 1.00, green: 0.40, blue: 0.30),  // coral
        Color(red: 1.00, green: 0.72, blue: 0.20),  // amber
        Color(red: 0.30, green: 0.85, blue: 0.80),  // cyan
        Color(red: 0.35, green: 0.50, blue: 1.00),  // azure
        Color(red: 0.42, green: 0.20, blue: 0.95)   // close the loop
    ]

    private var generatingView: some View {
        VStack(spacing: 20) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let rotation = Angle.degrees(t * 48)
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        AngularGradient(
                            colors: Self.intelligenceColors,
                            center: .center,
                            startAngle: rotation,
                            endAngle: rotation + .degrees(360)
                        )
                    )
                    .symbolEffect(.variableColor.iterative.reversing)
            }
            .frame(width: 70, height: 70)

            Text("Generating your \(noteFormat.rawValue) note")
                .font(.headline)
            Text("Apple Intelligence is summarising the transcript")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var intelligenceHalo: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let rotation = Angle.degrees(t * 36)
            let gradient = AngularGradient(
                colors: Self.intelligenceColors,
                center: .center,
                startAngle: rotation,
                endAngle: rotation + .degrees(360)
            )

            ZStack {
                // Outer soft glow — wide blurred stroke creating the halo bloom
                Rectangle()
                    .stroke(gradient, lineWidth: 28)
                    .blur(radius: 22)
                    .opacity(0.75)

                // Inner crisp gradient border
                Rectangle()
                    .strokeBorder(gradient, lineWidth: 3)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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

    private func insufficientView(_ reason: String) -> some View {
        ContentUnavailableView {
            Label("Not Enough Information", systemImage: "doc.text.magnifyingglass")
        } description: {
            VStack(spacing: 12) {
                Text(reason.isEmpty
                    ? "The recording doesn't contain enough clinical content to generate a note."
                    : reason)
                DisclosureGroup("View Transcript") {
                    Text(transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
            }
        } actions: {
            Button("Done") { dismissSheet = false }
                .buttonStyle(.borderedProminent)
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
                        regenerateFormat = noteFormat
                        showRegenerateSheet = true
                    } label: {
                        Label("Generate Another Note", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }

                    Button {
                        dismissSheet = false
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
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
                Section {
                    Picker("Format", selection: $regenerateFormat) {
                        ForEach(NoteFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Format")
                } footer: {
                    Text(formatDescription(regenerateFormat))
                }

                Section {
                    Picker("Tone", selection: $regenerateTone) {
                        ForEach(NoteTone.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Tone")
                } footer: {
                    Text(regenerateTone.description)
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

    private func formatDescription(_ format: NoteFormat) -> String {
        switch format {
        case .soap:
            return "Subjective, Objective, Assessment, Plan"
        case .dap:
            return "Data, Assessment, Plan"
        case .goalFocused:
            return "Session observations and per-goal breakdown"
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
                guard note.hasSufficientContent else {
                    insufficientContentReason = note.insufficientContentReason
                    isGenerating = false
                    return
                }
                subjective = note.subjective
                objective = note.objective
                assessment = note.assessment
                plan = note.plan
                goalsAddressed = note.goalsAddressed
                timeSpent = note.timeSpent
                interventionsUsed = note.interventionsUsed
            case .dap:
                let note = try await NoteGenerationService.generateDAP(transcript: transcript, tone: currentTone)
                guard note.hasSufficientContent else {
                    insufficientContentReason = note.insufficientContentReason
                    isGenerating = false
                    return
                }
                data = note.data
                assessment = note.assessment
                plan = note.plan
                goalsAddressed = note.goalsAddressed
                timeSpent = note.timeSpent
                interventionsUsed = note.interventionsUsed
            case .goalFocused:
                let note = try await NoteGenerationService.generateGoalFocused(transcript: transcript, tone: currentTone)
                guard note.hasSufficientContent else {
                    insufficientContentReason = note.insufficientContentReason
                    isGenerating = false
                    return
                }
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
            clientName: clientName,
            client: client,
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

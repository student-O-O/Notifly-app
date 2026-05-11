import SwiftUI
import SwiftData
import FoundationModels

struct ReviewNoteView: View {
    let clientInitials: String
    let noteFormat: NoteFormat
    let transcript: String
    var customTemplate: NoteTemplate?
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

    @State private var customSectionContents: [String: String] = [:]
    @State private var tableData: CustomTableData?

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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(saved)
        #endif
        .task {
            await generateNote()
        }
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Generating your \(displayName) note...")
                .foregroundStyle(.secondary)
        }
    }

    private var displayName: String {
        if noteFormat == .custom, let name = customTemplate?.name {
            return name
        }
        return noteFormat.rawValue
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
                commonFields
            case .dap:
                dapFields
                commonFields
            case .custom:
                if customTemplate?.isTableFormat == true {
                    tableFields
                } else {
                    customFields
                }
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
    private var customFields: some View {
        if let template = customTemplate {
            ForEach(template.sectionTitles, id: \.self) { title in
                Section(title) {
                    TextEditor(text: Binding(
                        get: { customSectionContents[title] ?? "" },
                        set: { customSectionContents[title] = $0 }
                    ))
                    .frame(minHeight: 80)
                }
            }
        }
    }

    @ViewBuilder
    private var tableFields: some View {
        if let table = tableData {
            ForEach(table.rows.indices, id: \.self) { rowIndex in
                Section {
                    Text(table.rows[rowIndex].first ?? "")
                        .font(.headline)
                        .padding(.vertical, 4)

                    ForEach(1..<table.columns.count, id: \.self) { colIndex in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(table.columns[colIndex])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: Binding(
                                get: {
                                    guard rowIndex < (tableData?.rows.count ?? 0),
                                          colIndex < (tableData?.rows[rowIndex].count ?? 0) else { return "" }
                                    return tableData!.rows[rowIndex][colIndex]
                                },
                                set: { tableData?.rows[rowIndex][colIndex] = $0 }
                            ))
                            .frame(minHeight: 60)
                        }
                    }
                } header: {
                    Text("\(table.columns.first ?? "Entry") \(rowIndex + 1)")
                }
            }

            Section {
                Button {
                    let emptyRow = Array(repeating: "", count: table.columns.count)
                    tableData?.rows.append(emptyRow)
                } label: {
                    Label("Add \(table.columns.first ?? "Entry")", systemImage: "plus.circle")
                }
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
            case .custom:
                if let template = customTemplate {
                    if template.isTableFormat {
                        tableData = try await NoteGenerationService.generateGoalEntries(
                            transcript: transcript,
                            fieldNames: template.sectionTitles,
                            promptInstructions: template.promptInstructions.isEmpty ? nil : template.promptInstructions
                        )
                    } else {
                        let sections = try await NoteGenerationService.generateCustom(
                            transcript: transcript,
                            sectionTitles: template.sectionTitles,
                            promptInstructions: template.promptInstructions.isEmpty ? nil : template.promptInstructions
                        )
                        for section in sections {
                            customSectionContents[section.title] = section.content
                        }
                    }
                }
            }
            isGenerating = false
        } catch {
            generationError = error.localizedDescription
            isGenerating = false
        }
    }

    private func saveNote() {
        if noteFormat == .custom, let template = customTemplate {
            if template.isTableFormat, let table = tableData {
                let note = SessionNote(
                    clientInitials: clientInitials,
                    noteFormat: .custom,
                    transcript: transcript,
                    templateName: template.name,
                    customTableData: table,
                    isTableFormat: true
                )
                modelContext.insert(note)
            } else {
                let sections = template.sectionTitles.map { title in
                    CustomSection(title: title, content: customSectionContents[title] ?? "")
                }
                let note = SessionNote(
                    clientInitials: clientInitials,
                    noteFormat: .custom,
                    transcript: transcript,
                    templateName: template.name,
                    customSections: sections
                )
                modelContext.insert(note)
            }
        } else {
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
        }
        saved = true
        onComplete()
    }
}

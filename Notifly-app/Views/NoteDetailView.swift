import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct NoteDetailView: View {
    @Bindable var note: SessionNote
    var popToRoot: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var showTranscript = false
    @State private var showDeleteTranscriptAlert = false
    @State private var showCopiedToast = false
    @State private var showRegenerateSheet = false
    @State private var regenerateTone: NoteTone = .standard
    @State private var regenerateFormat: NoteFormat = .soap
    @State private var navigateToRegenerated = false
    @State private var showAssignClientSheet = false

    var body: some View {
        Form {
            headerSection

            if note.client == nil {
                Section {
                    Button {
                        showAssignClientSheet = true
                    } label: {
                        Label("Assign to Client", systemImage: "person.crop.circle.badge.plus")
                    }
                } footer: {
                    Text("This note isn't linked to a client profile. Assign it to group it with that client's other notes.")
                }
            }

            if let transcript = note.transcript, !transcript.isEmpty {
                transcriptSection(transcript)
            }

            noteSections

            exportSection

            if note.transcript?.isEmpty == false {
                Section {
                    Button {
                        regenerateTone = note.tone
                        regenerateFormat = note.noteFormat
                        showRegenerateSheet = true
                    } label: {
                        Label("Generate Another Note", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("\(note.displayName) Note")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                copiedToast
            }
        }
        .sheet(isPresented: $showRegenerateSheet) {
            regenerateSheet
        }
        .sheet(isPresented: $showAssignClientSheet) {
            AssignClientSheet(note: note, isPresented: $showAssignClientSheet)
        }
        .navigationDestination(isPresented: $navigateToRegenerated) {
            ReviewNoteView(
                clientName: note.clientName,
                client: note.client,
                noteFormat: regenerateFormat,
                tone: regenerateTone,
                sessionID: note.sessionID,
                transcript: note.transcript ?? "",
                dismissSheet: regeneratedDoneBinding
            )
        }
        .alert("Delete Transcript?", isPresented: $showDeleteTranscriptAlert) {
            Button("Delete", role: .destructive) {
                note.transcript = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The raw transcript will be permanently removed. The structured note will remain.")
        }
    }

    private var headerSection: some View {
        Section {
            LabeledContent("Client", value: note.clientName)
            if isEditing {
                DatePicker("Date", selection: $note.date)
            } else {
                LabeledContent("Date", value: note.date.formatted(date: .long, time: .shortened))
            }
            LabeledContent("Format", value: note.displayName)
            LabeledContent("Tone", value: note.tone.rawValue)
        }
    }

    private func transcriptSection(_ transcript: String) -> some View {
        Section {
            DisclosureGroup("Raw Transcript", isExpanded: $showTranscript) {
                Text(transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Delete Transcript", role: .destructive) {
                    showDeleteTranscriptAlert = true
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var noteSections: some View {
        if note.noteFormat == .goalFocused {
            goalFocusedSections
        } else {
            builtInNoteSections
        }
    }

    @ViewBuilder
    private var builtInNoteSections: some View {
        ForEach(note.sections, id: \.title) { section in
            Section(section.title) {
                if isEditing {
                    TextEditor(text: Binding(
                        get: { note[keyPath: section.keyPath] },
                        set: { note[keyPath: section.keyPath] = $0 }
                    ))
                    .frame(minHeight: 60)
                } else {
                    let value = note[keyPath: section.keyPath]
                    if value.isEmpty {
                        Text("No content")
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        Text(value)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var goalFocusedSections: some View {
        Section("Session Observations") {
            if isEditing {
                TextEditor(text: $note.sessionObservations)
                    .frame(minHeight: 60)
            } else if note.sessionObservations.isEmpty {
                Text("No content")
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(note.sessionObservations)
            }
        }

        let cards = note.goalCards
        ForEach(cards.indices, id: \.self) { index in
            Section {
                if isEditing {
                    TextField("Goal", text: Binding(
                        get: { note.goalCards.indices.contains(index) ? note.goalCards[index].goal : "" },
                        set: { newValue in
                            var updated = note.goalCards
                            guard updated.indices.contains(index) else { return }
                            updated[index].goal = newValue
                            note.goalCards = updated
                        }
                    ), axis: .vertical)
                        .font(.headline)
                        .padding(.vertical, 4)

                    goalFieldEditor("Activities", index: index, keyPath: \.activities)
                    goalFieldEditor("Observations", index: index, keyPath: \.observations)
                    goalFieldEditor("Next Steps", index: index, keyPath: \.nextSteps)
                } else {
                    Text(cards[index].goal)
                        .font(.headline)
                        .padding(.vertical, 4)

                    goalFieldDisplay("Activities", value: cards[index].activities)
                    goalFieldDisplay("Observations", value: cards[index].observations)
                    goalFieldDisplay("Next Steps", value: cards[index].nextSteps)
                }
            } header: {
                Text(cards.count > 1 ? "Goal \(index + 1)" : "Goal")
            }
        }

        if isEditing {
            Section {
                Button {
                    var updated = note.goalCards
                    updated.append(GoalCard(goal: "", activities: "", observations: "", nextSteps: ""))
                    note.goalCards = updated
                } label: {
                    Label("Add Goal", systemImage: "plus.circle")
                }

                if !note.goalCards.isEmpty {
                    Button(role: .destructive) {
                        var updated = note.goalCards
                        updated.removeLast()
                        note.goalCards = updated
                    } label: {
                        Label("Remove Last Goal", systemImage: "minus.circle")
                    }
                }
            }
        }
    }

    private func goalFieldEditor(_ label: String, index: Int, keyPath: WritableKeyPath<GoalCard, String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { note.goalCards.indices.contains(index) ? note.goalCards[index][keyPath: keyPath] : "" },
                set: { newValue in
                    var updated = note.goalCards
                    guard updated.indices.contains(index) else { return }
                    updated[index][keyPath: keyPath] = newValue
                    note.goalCards = updated
                }
            ))
            .frame(minHeight: 60)
        }
    }

    @ViewBuilder
    private func goalFieldDisplay(_ label: String, value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
            }
            .padding(.vertical, 2)
        }
    }

    private var exportSection: some View {
        Section {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = note.asPlainText()
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.asPlainText(), forType: .string)
                #endif
                withAnimation {
                    showCopiedToast = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        showCopiedToast = false
                    }
                }
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
            }

            ShareLink(item: note.asPlainText()) {
                Label("Share Note", systemImage: "square.and.arrow.up")
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

    private var regeneratedDoneBinding: Binding<Bool> {
        Binding(
            get: { navigateToRegenerated },
            set: { newValue in
                if newValue {
                    navigateToRegenerated = true
                } else {
                    popToRoot()
                }
            }
        )
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

    private var copiedToast: some View {
        Text("Copied!")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct AssignClientSheet: View {
    @Bindable var note: SessionNote
    @Binding var isPresented: Bool
    @Query(sort: [SortDescriptor(\Client.lastName), SortDescriptor(\Client.firstName)]) private var clients: [Client]
    @State private var searchText = ""

    private var filteredClients: [Client] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return clients }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return clients.filter {
            $0.firstName.range(of: trimmed, options: options) != nil
                || $0.lastName.range(of: trimmed, options: options) != nil
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    ContentUnavailableView {
                        Label("No Clients", systemImage: "person.crop.circle")
                    } description: {
                        Text("Create a client first to assign this note.")
                    }
                } else {
                    List {
                        ForEach(filteredClients) { client in
                            Button {
                                assign(client)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(.tint.opacity(0.15)).frame(width: 32, height: 32)
                                        Text(client.initials)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tint)
                                    }
                                    Text(client.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search clients")
                }
            }
            .navigationTitle("Assign to Client")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func assign(_ client: Client) {
        note.client = client
        note.clientName = client.displayName
        isPresented = false
    }
}

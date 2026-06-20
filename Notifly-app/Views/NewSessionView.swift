import SwiftUI
import SwiftData

struct NewSessionView: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @Query private var clients: [Client]

    @AppStorage("defaultNoteFormat") private var defaultFormatRaw: String = NoteFormat.soap.rawValue

    @State private var selectedClient: Client?
    @State private var clientSearchText = ""
    @State private var noteFormat: NoteFormat
    @State private var selectedTone: NoteTone = .standard
    @State private var navigateToRecording = false
    @State private var showNewClientSheet = false

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let storedRaw = UserDefaults.standard.string(forKey: "defaultNoteFormat") ?? NoteFormat.soap.rawValue
        _noteFormat = State(initialValue: NoteFormat(rawValue: storedRaw) ?? .soap)
    }

    private var defaultFormat: NoteFormat {
        NoteFormat(rawValue: defaultFormatRaw) ?? .soap
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    clientSection
                }

                Section {
                    Picker("Format", selection: $noteFormat) {
                        ForEach(NoteFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)

                    if noteFormat == defaultFormat {
                        Label("Default for new sessions", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            defaultFormatRaw = noteFormat.rawValue
                        } label: {
                            Label("Set \(noteFormat.rawValue) as Default", systemImage: "star")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Format")
                } footer: {
                    Text(formatDescription)
                }

                Section {
                    Picker("Tone", selection: $selectedTone) {
                        ForEach(NoteTone.allCases) { tone in
                            Text(tone.rawValue).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Tone")
                } footer: {
                    Text(selectedTone.description)
                }

                Section {
                    Button {
                        navigateToRecording = true
                    } label: {
                        Label("Start Recording", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .disabled(!canStart)
                } footer: {
                    if !canStart {
                        Text("Choose a client to begin.")
                    }
                }
            }
            .navigationTitle("New Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToRecording) {
                if let client = selectedClient {
                    RecordingView(
                        client: client,
                        noteFormat: noteFormat,
                        tone: selectedTone,
                        dismissSheet: $isPresented
                    )
                }
            }
            .sheet(isPresented: $showNewClientSheet) {
                ClientEditorView(
                    isPresented: $showNewClientSheet,
                    onSave: { newClient in
                        selectedClient = newClient
                        clientSearchText = ""
                    }
                )
            }
        }
    }

    private var filteredClients: [Client] {
        let trimmed = clientSearchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .anchored, .diacriticInsensitive]
        return clients.filter {
            $0.firstName.range(of: trimmed, options: options) != nil
                || $0.lastName.range(of: trimmed, options: options) != nil
        }
    }

    @ViewBuilder
    private var clientSection: some View {
        if clients.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No clients yet.")
                    .foregroundStyle(.secondary)
                Button {
                    showNewClientSheet = true
                } label: {
                    Label("Create your first client profile", systemImage: "plus.circle.fill")
                }
            }
            .padding(.vertical, 4)
        } else if let client = selectedClient {
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
                Button {
                    selectedClient = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change client")
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clients", text: $clientSearchText)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .autocorrectionDisabled()
                if !clientSearchText.isEmpty {
                    Button {
                        clientSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(filteredClients.prefix(8)) { client in
                clientSearchResultRow(client)
            }

            if !clientSearchText.trimmingCharacters(in: .whitespaces).isEmpty && filteredClients.isEmpty {
                Text("No matching clients.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showNewClientSheet = true
            } label: {
                Label("New Client", systemImage: "plus.circle")
            }
        }
    }

    private func clientSearchResultRow(_ client: Client) -> some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            selectedClient = client
            clientSearchText = ""
        }
    }

    private var canStart: Bool {
        selectedClient != nil
    }

    private var formatDescription: String {
        switch noteFormat {
        case .soap:
            return "Subjective, Objective, Assessment, Plan"
        case .dap:
            return "Data, Assessment, Plan"
        case .goalFocused:
            return "Session observations and per-goal breakdown"
        }
    }
}

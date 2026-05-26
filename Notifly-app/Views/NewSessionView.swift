import SwiftUI
import SwiftData

struct NewSessionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var clientInitials = ""
    @State private var noteFormat: NoteFormat = .soap
    @State private var selectedTone: NoteTone = .standard
    @State private var navigateToRecording = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    TextField("Client Initials (e.g. JD)", text: $clientInitials)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()
                }

                Section("Format") {
                    Picker("Format", selection: $noteFormat) {
                        ForEach(NoteFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(formatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Tone") {
                    Picker("Tone", selection: $selectedTone) {
                        ForEach(NoteTone.allCases) { tone in
                            Text(tone.rawValue).tag(tone)
                        }
                    }

                    Text(selectedTone.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                RecordingView(
                    clientInitials: clientInitials.trimmingCharacters(in: .whitespaces),
                    noteFormat: noteFormat,
                    tone: selectedTone,
                    onComplete: { dismiss() }
                )
            }
        }
    }

    private var canStart: Bool {
        !clientInitials.trimmingCharacters(in: .whitespaces).isEmpty
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

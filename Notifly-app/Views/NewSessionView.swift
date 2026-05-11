import SwiftUI
import SwiftData

struct NewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NoteTemplate.dateCreated, order: .reverse) private var templates: [NoteTemplate]

    @State private var clientInitials = ""
    @State private var selectedFormatID: String = NoteFormat.soap.rawValue
    @State private var navigateToRecording = false

    private var noteFormat: NoteFormat {
        NoteFormat(rawValue: selectedFormatID) ?? .custom
    }

    private var selectedTemplate: NoteTemplate? {
        templates.first(where: { $0.id.uuidString == selectedFormatID })
    }

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
                    Picker("Format", selection: $selectedFormatID) {
                        ForEach(NoteFormat.builtInFormats) { format in
                            Text(format.rawValue).tag(format.rawValue)
                        }

                        if !templates.isEmpty {
                            Divider()

                            ForEach(templates) { template in
                                HStack {
                                    Text(template.name)
                                    Text("Custom")
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.fill.tertiary)
                                        .clipShape(Capsule())
                                }
                                .tag(template.id.uuidString)
                            }
                        }
                    }

                    Text(formatDescription)
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
                    customTemplate: selectedTemplate,
                    onComplete: { dismiss() }
                )
            }
        }
    }

    private var canStart: Bool {
        let hasInitials = !clientInitials.trimmingCharacters(in: .whitespaces).isEmpty
        if noteFormat == .custom {
            return hasInitials && selectedTemplate != nil
        }
        return hasInitials
    }

    private var formatDescription: String {
        switch noteFormat {
        case .soap:
            return "Subjective, Objective, Assessment, Plan"
        case .dap:
            return "Data, Assessment, Plan"
        case .custom:
            if let template = selectedTemplate {
                return template.sectionTitles.joined(separator: ", ")
            }
            return "Select a template from the dropdown"
        }
    }
}

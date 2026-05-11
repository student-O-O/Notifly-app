import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var existingTemplate: NoteTemplate?

    @State private var name = ""
    @State private var sectionTitles: [String] = [""]
    @State private var promptInstructions = ""
    @State private var isTableFormat = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g. Initial Assessment", text: $name)
                }

                Section {
                    Toggle("Multi-Goal Format", isOn: $isTableFormat)
                } footer: {
                    Text(isTableFormat
                        ? "The AI will extract each goal as a separate card with these fields. Exports as a table."
                        : "The AI will return text blocks for each section.")
                }

                Section {
                    ForEach(sectionTitles.indices, id: \.self) { index in
                        TextField(isTableFormat ? "Field name" : "Section title", text: $sectionTitles[index])
                    }
                    .onDelete { offsets in
                        sectionTitles.remove(atOffsets: offsets)
                    }

                    Button {
                        sectionTitles.append("")
                    } label: {
                        Label(isTableFormat ? "Add Field" : "Add Section", systemImage: "plus.circle")
                    }
                } header: {
                    Text(isTableFormat ? "Fields per Goal" : "Sections")
                } footer: {
                    Text(isTableFormat
                        ? "The first field is used as the card header (e.g. Goal). The rest are fields within each card."
                        : "Define the sections you want the AI to fill in.")
                }

                Section {
                    TextEditor(text: $promptInstructions)
                        .frame(minHeight: 80)
                } header: {
                    Text("AI Instructions (Optional)")
                } footer: {
                    Text("Extra guidance for how the AI should write the note, e.g. \"Focus on functional outcomes\" or \"Use bullet points\".")
                }
            }
            .navigationTitle(existingTemplate == nil ? "New Template" : "Edit Template")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let template = existingTemplate {
                    name = template.name
                    sectionTitles = template.sectionTitles
                    promptInstructions = template.promptInstructions
                    isTableFormat = template.isTableFormat
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !validSectionTitles.isEmpty
    }

    private var validSectionTitles: [String] {
        sectionTitles
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func saveTemplate() {
        if let template = existingTemplate {
            template.name = name.trimmingCharacters(in: .whitespaces)
            template.sectionTitles = validSectionTitles
            template.promptInstructions = promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
            template.isTableFormat = isTableFormat
        } else {
            let template = NoteTemplate(
                name: name.trimmingCharacters(in: .whitespaces),
                sectionTitles: validSectionTitles,
                promptInstructions: promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
                isTableFormat: isTableFormat
            )
            modelContext.insert(template)
        }
        dismiss()
    }
}

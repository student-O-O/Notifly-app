import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct NoteDetailView: View {
    @Bindable var note: SessionNote
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var showTranscript = false
    @State private var showDeleteTranscriptAlert = false
    @State private var showCopiedToast = false

    var body: some View {
        Form {
            headerSection

            if let transcript = note.transcript, !transcript.isEmpty {
                transcriptSection(transcript)
            }

            noteSections

            exportSection
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
            LabeledContent("Client", value: note.clientInitials)
            LabeledContent("Date", value: note.date.formatted(date: .long, time: .shortened))
            LabeledContent("Format", value: note.displayName)
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
        if note.noteFormat == .custom && note.isTableFormat {
            tableNoteSections
        } else if note.noteFormat == .custom {
            customNoteSections
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
    private var customNoteSections: some View {
        let sections = note.customSections
        ForEach(sections.indices, id: \.self) { index in
            Section(sections[index].title) {
                if isEditing {
                    TextEditor(text: Binding(
                        get: { note.customSections[index].content },
                        set: {
                            var updated = note.customSections
                            updated[index].content = $0
                            note.customSections = updated
                        }
                    ))
                    .frame(minHeight: 60)
                } else {
                    if sections[index].content.isEmpty {
                        Text("No content")
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        Text(sections[index].content)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tableNoteSections: some View {
        if let table = note.customTableData {
            ForEach(table.rows.indices, id: \.self) { rowIndex in
                Section {
                    if isEditing {
                        ForEach(table.columns.indices, id: \.self) { colIndex in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(table.columns[colIndex])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: Binding(
                                    get: {
                                        guard let t = note.customTableData,
                                              rowIndex < t.rows.count,
                                              colIndex < t.rows[rowIndex].count else { return "" }
                                        return t.rows[rowIndex][colIndex]
                                    },
                                    set: {
                                        var updated = note.customTableData
                                        updated?.rows[rowIndex][colIndex] = $0
                                        note.customTableData = updated
                                    }
                                ))
                                .frame(minHeight: 60)
                            }
                        }
                    } else {
                        Text(table.rows[rowIndex].first ?? "")
                            .font(.headline)
                            .padding(.vertical, 4)

                        ForEach(1..<table.columns.count, id: \.self) { colIndex in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(table.columns[colIndex])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(table.rows[rowIndex][colIndex])
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("\(table.columns.first ?? "Entry") \(rowIndex + 1)")
                }
            }

            if isEditing {
                Section {
                    Button {
                        var updated = note.customTableData
                        let emptyRow = Array(repeating: "", count: table.columns.count)
                        updated?.rows.append(emptyRow)
                        note.customTableData = updated
                    } label: {
                        Label("Add \(table.columns.first ?? "Entry")", systemImage: "plus.circle")
                    }

                    if !table.rows.isEmpty {
                        Button(role: .destructive) {
                            var updated = note.customTableData
                            updated?.rows.removeLast()
                            note.customTableData = updated
                        } label: {
                            Label("Remove Last", systemImage: "minus.circle")
                        }
                    }
                }
            }
        } else {
            Section {
                Text("No data")
                    .foregroundStyle(.tertiary)
                    .italic()
            }
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

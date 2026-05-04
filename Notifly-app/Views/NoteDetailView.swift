import SwiftUI
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
        .navigationTitle("\(note.noteFormat.rawValue) Note")
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
            LabeledContent("Format", value: note.noteFormat.rawValue)
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

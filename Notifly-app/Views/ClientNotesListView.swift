import SwiftUI
import SwiftData

struct ClientNotesListView: View {
    @Bindable var client: Client
    @Environment(\.modelContext) private var modelContext
    @State private var noteToDelete: SessionNote?

    var body: some View {
        List {
            ForEach(client.notesNewestFirst) { note in
                NavigationLink {
                    NoteDetailView(note: note)
                } label: {
                    ClientNoteRow(note: note)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        noteToDelete = note
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("All Notes")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Delete Note?", isPresented: Binding(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let n = noteToDelete {
                    withAnimation { modelContext.delete(n) }
                }
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) { noteToDelete = nil }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }
}

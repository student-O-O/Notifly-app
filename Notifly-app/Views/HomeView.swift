import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionNote.date, order: .reverse) private var notes: [SessionNote]
    @State private var showNewSession = false

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("NOTIFLY")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showNewSession = true
                    } label: {
                        Label("New Session", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showNewSession) {
                NewSessionView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Sessions Yet", systemImage: "note.text")
        } description: {
            Text("Tap New Session to record your first clinical note.")
        }
    }

    private var notesList: some View {
        List {
            ForEach(notes) { note in
                NavigationLink(destination: NoteDetailView(note: note)) {
                    NoteRow(note: note)
                }
            }
            .onDelete(perform: deleteNotes)
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(notes[index])
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: SessionNote.self, inMemory: true)
}

struct NoteRow: View {
    let note: SessionNote

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.clientInitials)
                    .font(.headline)
                Text(note.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(note.noteFormat.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

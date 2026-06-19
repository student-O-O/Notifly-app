import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionNote.date, order: .reverse) private var notes: [SessionNote]
    @State private var showNewSession = false
    @State private var expandedSessions: Set<UUID> = []
    @State private var noteToDelete: SessionNote?
    @State private var sessionToDelete: UUID?
    @State private var navigationPath: [SessionNote] = []

    private var groupedSessions: [(id: UUID, date: Date, clientInitials: String, notes: [SessionNote])] {
        let grouped = Dictionary(grouping: notes, by: \.sessionID)
        return grouped.map { (id: $0.key, notes: $0.value) }
            .map { (id: $0.id, date: $0.notes.map(\.date).max() ?? Date(), clientInitials: $0.notes.first?.clientInitials ?? "", notes: $0.notes.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if notes.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationDestination(for: SessionNote.self) { note in
                NoteDetailView(note: note, popToRoot: { navigationPath.removeAll() })
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
                NewSessionView(isPresented: $showNewSession)
            }
            .alert("Delete Note?", isPresented: Binding(
                get: { noteToDelete != nil },
                set: { if !$0 { noteToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        withAnimation { modelContext.delete(note) }
                    }
                    noteToDelete = nil
                }
                Button("Cancel", role: .cancel) { noteToDelete = nil }
            } message: {
                Text("This note will be permanently deleted.")
            }
            .alert("Delete All Notes in Session?", isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            )) {
                Button("Delete All", role: .destructive) {
                    if let sid = sessionToDelete {
                        withAnimation {
                            for note in notes where note.sessionID == sid {
                                modelContext.delete(note)
                            }
                        }
                    }
                    sessionToDelete = nil
                }
                Button("Cancel", role: .cancel) { sessionToDelete = nil }
            } message: {
                if let sid = sessionToDelete {
                    let count = notes.filter { $0.sessionID == sid }.count
                    Text("All \(count) notes from this session will be permanently deleted.")
                }
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

    private var sessionList: some View {
        List {
            ForEach(groupedSessions, id: \.id) { session in
                if session.notes.count == 1 {
                    let note = session.notes[0]
                    NavigationLink(value: note) {
                        NoteRow(note: note)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            noteToDelete = note
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else {
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedSessions.contains(session.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedSessions.insert(session.id)
                            } else {
                                expandedSessions.remove(session.id)
                            }
                        }
                    )) {
                        ForEach(session.notes) { note in
                            NavigationLink(value: note) {
                                SessionChildRow(note: note)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    noteToDelete = note
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        SessionGroupRow(session: session)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            sessionToDelete = session.id
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

struct SessionGroupRow: View {
    let session: (id: UUID, date: Date, clientInitials: String, notes: [SessionNote])

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.clientInitials)
                    .font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(session.notes.count) notes")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

struct SessionChildRow: View {
    let note: SessionNote

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayName)
                    .font(.subheadline.weight(.medium))
                if !note.toneLabel.isEmpty {
                    Text(note.toneLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(note.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.tint.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

struct NoteRow: View {
    let note: SessionNote

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.clientInitials)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(note.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !note.toneLabel.isEmpty {
                        Text("· \(note.toneLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(note.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: SessionNote.self, inMemory: true)
}

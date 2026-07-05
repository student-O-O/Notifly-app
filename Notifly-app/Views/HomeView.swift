import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionNote.date, order: .reverse) private var notes: [SessionNote]
    @Query private var clients: [Client]
    @State private var showNewSession = false
    @State private var expandedSessions: Set<UUID> = []
    @State private var noteToDelete: SessionNote?
    @State private var sessionToDelete: UUID?
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""

    private let recentClientsLimit = 5

    struct SessionGroup: Identifiable {
        let id: UUID
        let date: Date
        let clientName: String
        let notes: [SessionNote]
    }

    private var groupedSessions: [SessionGroup] {
        let grouped = Dictionary(grouping: notes, by: \.sessionID)
        return grouped.map { key, value in
            SessionGroup(
                id: key,
                date: value.map(\.date).max() ?? Date(),
                clientName: value.first?.clientName ?? "",
                notes: value.sorted { $0.date > $1.date }
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var filteredGroupedSessions: [SessionGroup] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return groupedSessions }
        return groupedSessions.filter {
            $0.clientName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var bucketedSessions: [(label: String, sessions: [SessionGroup])] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        var today: [SessionGroup] = []
        var thisWeek: [SessionGroup] = []
        var earlier: [SessionGroup] = []
        for session in filteredGroupedSessions {
            if calendar.isDateInToday(session.date) {
                today.append(session)
            } else if let weekStart, session.date >= weekStart {
                thisWeek.append(session)
            } else {
                earlier.append(session)
            }
        }
        var result: [(label: String, sessions: [SessionGroup])] = []
        if !today.isEmpty { result.append(("Today", today)) }
        if !thisWeek.isEmpty { result.append(("This Week", thisWeek)) }
        if !earlier.isEmpty { result.append(("Earlier", earlier)) }
        return result
    }

    private var recentClients: [Client] {
        clients
            .compactMap { client -> (Client, Date)? in
                guard let date = client.lastSessionDate else { return nil }
                return (client, date)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(recentClientsLimit)
            .map { $0.0 }
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
                NoteDetailView(note: note, popToRoot: { navigationPath = NavigationPath() })
            }
            .navigationDestination(for: Client.self) { client in
                ClientDetailView(client: client)
            }
            .navigationTitle("NOTIFLY")
            #if os(iOS)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search by client")
            #else
            .searchable(text: $searchText, prompt: "Search by client")
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ClientListView()
                    } label: {
                        Label("Clients", systemImage: "person.2")
                    }
                }
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

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sessionList: some View {
        List {
            if !isSearching && !recentClients.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentClients) { client in
                                NavigationLink(value: client) {
                                    RecentClientChip(client: client)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Recent Clients")
                }
            }

            if isSearching && bucketedSessions.isEmpty {
                Section {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(bucketedSessions, id: \.label) { bucket in
                    Section(bucket.label) {
                        ForEach(bucket.sessions) { session in
                            sessionRow(for: session)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.immediately)
        #endif
    }

    @ViewBuilder
    private func sessionRow(for session: SessionGroup) -> some View {
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

struct RecentClientChip: View {
    let client: Client

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 52, height: 52)
                Text(client.initials)
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
            Text(client.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(lastSessionLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 84)
    }

    private var lastSessionLabel: String {
        guard let date = client.lastSessionDate else { return "" }
        return date.formatted(.relative(presentation: .named))
    }
}

struct SessionGroupRow: View {
    let session: HomeView.SessionGroup

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.clientName)
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
                Text(note.clientName)
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
        .modelContainer(for: [SessionNote.self, Client.self], inMemory: true)
}

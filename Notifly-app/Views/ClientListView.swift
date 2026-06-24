import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Client.lastName), SortDescriptor(\Client.firstName)])
    private var clients: [Client]
    @State private var showNewClientSheet = false
    @State private var clientToEdit: Client?
    @State private var clientToDelete: Client?
    @State private var searchText = ""

    private var filteredClients: [Client] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return clients }
        return clients.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed)
                || $0.firstName.localizedCaseInsensitiveContains(trimmed)
                || $0.lastName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var groupedClients: [(letter: String, clients: [Client])] {
        let grouped = Dictionary(grouping: filteredClients) { client -> String in
            guard let first = client.lastName.trimmingCharacters(in: .whitespaces).first else { return "#" }
            let upper = String(first).uppercased()
            return upper.range(of: "^[A-Z]$", options: .regularExpression) != nil ? upper : "#"
        }
        return grouped.map { (letter: $0.key, clients: $0.value) }
            .sorted { a, b in
                if a.letter == "#" { return false }
                if b.letter == "#" { return true }
                return a.letter < b.letter
            }
    }

    var body: some View {
        Group {
            if clients.isEmpty {
                emptyState
            } else {
                clientList
            }
        }
        .navigationTitle("Clients")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search clients")
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewClientSheet = true
                } label: {
                    Label("New Client", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewClientSheet) {
            ClientEditorView(isPresented: $showNewClientSheet)
        }
        .sheet(item: $clientToEdit) { client in
            ClientEditorView(isPresented: editorPresentedBinding, editing: client)
        }
        .alert("Delete Client?", isPresented: Binding(
            get: { clientToDelete != nil },
            set: { if !$0 { clientToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let client = clientToDelete {
                    withAnimation { modelContext.delete(client) }
                }
                clientToDelete = nil
            }
            Button("Cancel", role: .cancel) { clientToDelete = nil }
        } message: {
            if let client = clientToDelete {
                Text("\(client.displayName) will be permanently deleted. Existing session notes will remain but will no longer be linked to a client.")
            }
        }
    }

    private var editorPresentedBinding: Binding<Bool> {
        Binding(
            get: { clientToEdit != nil },
            set: { if !$0 { clientToEdit = nil } }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Clients Yet", systemImage: "person.crop.circle")
        } description: {
            Text("Add a client to start tracking their sessions and goals.")
        } actions: {
            Button {
                showNewClientSheet = true
            } label: {
                Label("Add Client", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var clientList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    ForEach(groupedClients, id: \.letter) { group in
                        Section {
                            ForEach(group.clients) { client in
                                NavigationLink {
                                    ClientDetailView(client: client)
                                } label: {
                                    ClientRow(client: client)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        clientToDelete = client
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        clientToEdit = client
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        } header: {
                            Text(group.letter)
                                .id(group.letter)
                        }
                    }
                }
                #if os(iOS)
                .listSectionSpacing(.compact)
                #endif

                if groupedClients.count > 1 {
                    alphabetIndex(proxy: proxy)
                }
            }
        }
    }

    private func alphabetIndex(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(groupedClients.map(\.letter), id: \.self) { letter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                } label: {
                    Text(letter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 16, height: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 2)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Alphabet index")
    }

}

func goalStatusSubtitle(for goal: Goal) -> String {
    var parts: [String] = [goal.currentStatus.rawValue]
    switch goal.currentStatus {
    case .inProgress:
        if let date = goal.startedDate {
            parts.append("since \(date.formatted(date: .abbreviated, time: .omitted))")
        }
    case .achieved:
        if let date = goal.achievedDate {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
    case .notStarted:
        break
    }
    return parts.joined(separator: " · ")
}

struct ClientRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(client.initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.headline)
                Text(sessionSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var sessionSubtitle: String {
        let count = client.sessionNotes.count
        if count == 0 {
            return "No sessions yet"
        }
        if let last = client.lastSessionDate {
            return "\(count) session\(count == 1 ? "" : "s") · Last \(last.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(count) session\(count == 1 ? "" : "s")"
    }
}

#Preview {
    NavigationStack {
        ClientListView()
    }
    .modelContainer(for: [Client.self, SessionNote.self], inMemory: true)
}

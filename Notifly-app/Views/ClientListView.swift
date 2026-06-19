import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.createdAt, order: .reverse) private var clients: [Client]
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
        .navigationDestination(for: Client.self) { client in
            ClientDetailPlaceholder(client: client)
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
        List {
            ForEach(filteredClients) { client in
                NavigationLink(value: client) {
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
        }
    }
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

private struct ClientDetailPlaceholder: View {
    let client: Client

    var body: some View {
        ContentUnavailableView {
            Label(client.displayName, systemImage: "person.crop.circle")
        } description: {
            Text("Client detail screen is coming soon. Goals and sessions will live here.")
        }
        .navigationTitle(client.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        ClientListView()
    }
    .modelContainer(for: [Client.self, SessionNote.self], inMemory: true)
}

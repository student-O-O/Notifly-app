import SwiftUI
import SwiftData

struct ClientPickerView: View {
    @Binding var selectedClient: Client?
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.createdAt, order: .reverse) private var clients: [Client]
    @State private var showNewClientSheet = false
    @State private var searchText = ""

    private var filteredClients: [Client] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return clients }
        let options: String.CompareOptions = [.caseInsensitive, .anchored, .diacriticInsensitive]
        return clients.filter {
            $0.firstName.range(of: trimmed, options: options) != nil
                || $0.lastName.range(of: trimmed, options: options) != nil
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    emptyState
                } else {
                    clientList
                }
            }
            .navigationTitle("Select Client")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search clients")
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                if !clients.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showNewClientSheet = true
                        } label: {
                            Label("New Client", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewClientSheet) {
                ClientEditorView(
                    isPresented: $showNewClientSheet,
                    onSave: { newClient in
                        selectedClient = newClient
                        isPresented = false
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Clients Yet", systemImage: "person.crop.circle")
        } description: {
            Text("Create your first client profile to start recording sessions.")
        } actions: {
            Button {
                showNewClientSheet = true
            } label: {
                Label("Create Client", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var clientList: some View {
        List {
            ForEach(filteredClients) { client in
                ClientPickerRow(client: client, isSelected: client.id == selectedClient?.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedClient = client
                        isPresented = false
                    }
            }
        }
    }
}

struct ClientPickerRow: View {
    let client: Client
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.tint.opacity(0.15)).frame(width: 40, height: 40)
                Text(client.initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        let goals = client.activeGoals.count
        let sessions = client.sessionNotes.count
        if goals > 0 {
            parts.append("\(goals) goal\(goals == 1 ? "" : "s")")
        }
        if sessions > 0 {
            parts.append("\(sessions) session\(sessions == 1 ? "" : "s")")
        }
        if let last = client.lastSessionDate {
            parts.append("Last \(last.formatted(date: .abbreviated, time: .omitted))")
        }
        if parts.isEmpty { return "No sessions yet" }
        return parts.joined(separator: " · ")
    }
}

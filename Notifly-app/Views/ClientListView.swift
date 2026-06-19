import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.createdAt, order: .reverse) private var clients: [Client]
    @State private var showNewClientSheet = false
    @State private var clientToEdit: Client?
    @State private var clientToDelete: Client?
    @State private var newGoalClient: Client?
    @State private var expandedClients: Set<UUID> = []
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
        .sheet(isPresented: $showNewClientSheet) {
            ClientEditorView(isPresented: $showNewClientSheet)
        }
        .sheet(item: $clientToEdit) { client in
            ClientEditorView(isPresented: editorPresentedBinding, editing: client)
        }
        .sheet(item: $newGoalClient) { client in
            GoalEditorView(isPresented: newGoalPresentedBinding, client: client)
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

    private var newGoalPresentedBinding: Binding<Bool> {
        Binding(
            get: { newGoalClient != nil },
            set: { if !$0 { newGoalClient = nil } }
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
                Section {
                    clientHeaderRow(for: client)
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

                    if expandedClients.contains(client.id) {
                        clientGoalContent(for: client)
                    }
                }
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    private func clientHeaderRow(for client: Client) -> some View {
        HStack {
            ClientRow(client: client)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expandedClients.contains(client.id) ? 90 : 0))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedClients.contains(client.id) {
                    expandedClients.remove(client.id)
                } else {
                    expandedClients.insert(client.id)
                }
            }
        }
    }

    @ViewBuilder
    private func clientGoalContent(for client: Client) -> some View {
        if client.activeGoals.isEmpty {
            Text("No goals yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
        } else {
            ForEach(client.activeGoals) { goal in
                goalRow(goal)
            }
        }

        if !client.archivedGoals.isEmpty {
            DisclosureGroup {
                ForEach(client.archivedGoals) { goal in
                    goalRow(goal)
                }
            } label: {
                Text("Archived (\(client.archivedGoals.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Button {
            newGoalClient = client
        } label: {
            Label("Add Goal", systemImage: "plus.circle")
                .font(.subheadline)
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        NavigationLink(destination: GoalDetailView(goal: goal)) {
            InlineGoalRow(goal: goal)
        }
    }
}

struct InlineGoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: goal.currentStatus.systemImage)
                .foregroundStyle(tintFor(goal.currentStatus))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(goal.title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        goalStatusSubtitle(for: goal)
    }

    private func tintFor(_ status: GoalStatus) -> Color {
        switch status {
        case .notStarted: return .secondary
        case .inProgress: return .blue
        case .achieved: return .green
        }
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

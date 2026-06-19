import SwiftUI
import SwiftData

struct ClientDetailView: View {
    @Bindable var client: Client
    @Environment(\.modelContext) private var modelContext

    @State private var showEditClient = false
    @State private var showNewGoal = false
    @State private var showArchived = false
    @State private var goalToDelete: Goal?

    var body: some View {
        List {
            Section { clientHeader }
            goalSection
            archivedGoalSection
        }
        .navigationTitle(client.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditClient = true }
            }
        }
        .navigationDestination(for: Goal.self) { goal in
            GoalDetailView(goal: goal)
        }
        .sheet(isPresented: $showEditClient) {
            ClientEditorView(isPresented: $showEditClient, editing: client)
        }
        .sheet(isPresented: $showNewGoal) {
            GoalEditorView(isPresented: $showNewGoal, client: client)
        }
        .alert("Delete Goal?", isPresented: Binding(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let g = goalToDelete {
                    withAnimation { modelContext.delete(g) }
                }
                goalToDelete = nil
            }
            Button("Cancel", role: .cancel) { goalToDelete = nil }
        } message: {
            Text("This goal and its full status history will be permanently deleted.")
        }
    }

    private var clientHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 56, height: 56)
                Text(client.initials)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.headline)
                Text("\(client.activeGoals.count) active goal\(client.activeGoals.count == 1 ? "" : "s") · \(client.sessionNotes.count) note\(client.sessionNotes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var goalSection: some View {
        Section {
            if client.activeGoals.isEmpty {
                Text("No active goals.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(client.activeGoals) { goal in
                    NavigationLink(value: goal) {
                        GoalRow(goal: goal)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            goalToDelete = goal
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            Button {
                showNewGoal = true
            } label: {
                Label("Add Goal", systemImage: "plus.circle")
            }
        } header: {
            Text("Goals")
        }
    }

    @ViewBuilder
    private var archivedGoalSection: some View {
        if !client.archivedGoals.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $showArchived) {
                    ForEach(client.archivedGoals) { goal in
                        NavigationLink(value: goal) {
                            GoalRow(goal: goal)
                        }
                    }
                } label: {
                    Text("Archived (\(client.archivedGoals.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: goal.currentStatus.systemImage)
                .foregroundStyle(tintFor(goal.currentStatus))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                Text(goalStatusSubtitle(for: goal))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func tintFor(_ status: GoalStatus) -> Color {
        switch status {
        case .notStarted: return .secondary
        case .inProgress: return .blue
        case .achieved: return .green
        }
    }
}

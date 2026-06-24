import SwiftUI
import SwiftData

struct ClientDetailView: View {
    @Bindable var client: Client
    @Environment(\.modelContext) private var modelContext

    @State private var showEditClient = false
    @State private var showNewGoal = false
    @State private var showArchived = false
    @State private var showAllGoals = false
    @State private var goalToDelete: Goal?
    @State private var noteToDelete: SessionNote?

    private let recentNotesLimit = 5
    private let activeGoalsLimit = 3

    var body: some View {
        List {
            Section { clientHeader }

            goalSection
            archivedGoalSection
            notesSection
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
        let activeGoals = client.activeGoals
        let visibleGoals = showAllGoals ? activeGoals : Array(activeGoals.prefix(activeGoalsLimit))

        Section {
            if activeGoals.isEmpty {
                Text("No active goals.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleGoals) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
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
                if activeGoals.count > activeGoalsLimit {
                    Button {
                        withAnimation { showAllGoals.toggle() }
                    } label: {
                        Label(
                            showAllGoals ? "Show Less" : "Show All Goals (\(activeGoals.count))",
                            systemImage: showAllGoals ? "chevron.up" : "chevron.down"
                        )
                        .font(.subheadline)
                    }
                }
            }
            Button {
                showNewGoal = true
            } label: {
                Label("Add Goal", systemImage: "plus.circle")
            }
        } header: {
            sectionHeader("Goals", count: activeGoals.count)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if count > 0 {
                Text("· \(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var archivedGoalSection: some View {
        if !client.archivedGoals.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $showArchived) {
                    ForEach(client.archivedGoals) { goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
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

    @ViewBuilder
    private var notesSection: some View {
        let allNotes = client.notesNewestFirst
        let recent = Array(allNotes.prefix(recentNotesLimit))

        Section {
            if allNotes.isEmpty {
                Text("No session notes yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { note in
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
                if allNotes.count > recentNotesLimit {
                    NavigationLink {
                        ClientNotesListView(client: client)
                    } label: {
                        Label("View All Notes", systemImage: "list.bullet.rectangle")
                            .font(.subheadline)
                    }
                }
            }
        } header: {
            sectionHeader("Session Notes", count: allNotes.count)
        }
    }
}

struct ClientNoteRow: View {
    let note: SessionNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(note.displayName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.tint.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private var snippet: String {
        if note.noteFormat == .goalFocused {
            let firstGoal = note.goalCards.first?.goal ?? ""
            return firstGoal.isEmpty ? note.sessionObservations : firstGoal
        }
        return note.sections
            .lazy
            .map { note[keyPath: $0.keyPath] }
            .first(where: { !$0.isEmpty }) ?? ""
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

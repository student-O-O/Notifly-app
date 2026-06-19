import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showStatusSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        Form {
            Section {
                statusRow
                if let started = goal.startedDate {
                    LabeledContent("Started", value: started.formatted(date: .long, time: .omitted))
                }
                if let achieved = goal.achievedDate {
                    LabeledContent("Achieved", value: achieved.formatted(date: .long, time: .omitted))
                }
                Button {
                    showStatusSheet = true
                } label: {
                    Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            if !goal.details.isEmpty {
                Section("Details") {
                    Text(goal.details)
                }
            }

            historySection

            Section {
                Button {
                    goal.archived.toggle()
                    try? modelContext.save()
                } label: {
                    Label(
                        goal.archived ? "Unarchive" : "Archive",
                        systemImage: goal.archived ? "tray.and.arrow.up" : "archivebox"
                    )
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Goal", systemImage: "trash")
                }
            }
        }
        .navigationTitle(goal.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showStatusSheet) {
            GoalStatusChangeSheet(isPresented: $showStatusSheet, goal: goal)
        }
        .sheet(isPresented: $showEditSheet) {
            GoalEditorView(isPresented: $showEditSheet, editing: goal)
        }
        .alert("Delete Goal?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(goal)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This goal and its full status history will be permanently deleted.")
        }
    }

    private var statusRow: some View {
        HStack {
            Label(goal.currentStatus.rawValue, systemImage: goal.currentStatus.systemImage)
                .labelStyle(.titleAndIcon)
                .foregroundStyle(statusTint(goal.currentStatus))
                .font(.headline)
            Spacer()
            if goal.archived {
                Text("Archived")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section("History") {
            if goal.history.isEmpty {
                Text("No history yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goal.sortedHistory) { entry in
                    GoalHistoryRow(entry: entry)
                }
            }
        }
    }
}

private func statusTint(_ status: GoalStatus) -> Color {
    switch status {
    case .notStarted: return .secondary
    case .inProgress: return .blue
    case .achieved: return .green
    }
}

struct GoalHistoryRow: View {
    let entry: GoalStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let old = entry.oldStatus {
                    Text(old.rawValue)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(entry.newStatus.rawValue)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusTint(entry.newStatus))
                Spacer()
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = entry.therapistNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let quote = entry.evidenceQuote, !quote.isEmpty {
                Text("\u{201C}\(quote)\u{201D}")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

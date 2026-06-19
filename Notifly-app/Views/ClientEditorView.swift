import SwiftUI
import SwiftData

struct ClientEditorView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editingClient: Client?
    @State private var firstName: String
    @State private var lastName: String
    @State private var goalEdits: [GoalEdit]
    @State private var deletedExistingGoals: [Goal] = []

    struct GoalEdit: Identifiable {
        let id = UUID()
        let existingGoal: Goal?
        var title: String
        var details: String
        var status: GoalStatus
        let originalTitle: String
        let originalDetails: String
        let originalStatus: GoalStatus

        init(existing goal: Goal) {
            self.existingGoal = goal
            self.title = goal.title
            self.details = goal.details
            self.status = goal.currentStatus
            self.originalTitle = goal.title
            self.originalDetails = goal.details
            self.originalStatus = goal.currentStatus
        }

        init(draft: Void = ()) {
            self.existingGoal = nil
            self.title = ""
            self.details = ""
            self.status = .notStarted
            self.originalTitle = ""
            self.originalDetails = ""
            self.originalStatus = .notStarted
        }
    }

    init(isPresented: Binding<Bool>, editing client: Client? = nil) {
        self._isPresented = isPresented
        self.editingClient = client
        _firstName = State(initialValue: client?.firstName ?? "")
        _lastName = State(initialValue: client?.lastName ?? "")
        if let client {
            _goalEdits = State(initialValue: client.activeGoals.map { GoalEdit(existing: $0) })
        } else {
            _goalEdits = State(initialValue: [GoalEdit()])
        }
    }

    private var trimmedFirst: String {
        firstName.trimmingCharacters(in: .whitespaces)
    }

    private var trimmedLast: String {
        lastName.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        !trimmedFirst.isEmpty && !trimmedLast.isEmpty
    }

    private var title: String {
        editingClient == nil ? "New Client" : "Edit Client"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled()
                    TextField("Last Name", text: $lastName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled()
                }

                goalsSection
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var goalsSection: some View {
        Section {
            ForEach($goalEdits) { $edit in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Goal title", text: $edit.title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Details (optional)", text: $edit.details, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Status", selection: $edit.status) {
                        ForEach(GoalStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.systemImage).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        removeGoalEdit(id: edit.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                goalEdits.append(GoalEdit())
            } label: {
                Label("Add Another Goal", systemImage: "plus.circle")
            }
        } header: {
            Text("Goals")
        } footer: {
            Text(editingClient == nil
                ? "Add the client's treatment goals and the current status of each. You can update these later as you review sessions."
                : "Edit goals inline. Status changes are recorded in the goal's history.")
        }
    }

    private func removeGoalEdit(id: UUID) {
        guard let idx = goalEdits.firstIndex(where: { $0.id == id }) else { return }
        if let goal = goalEdits[idx].existingGoal {
            deletedExistingGoals.append(goal)
        }
        goalEdits.remove(at: idx)
    }

    private func save() {
        let effectiveClient: Client
        if let client = editingClient {
            client.firstName = trimmedFirst
            client.lastName = trimmedLast
            effectiveClient = client
        } else {
            let client = Client(firstName: trimmedFirst, lastName: trimmedLast)
            modelContext.insert(client)
            effectiveClient = client
        }

        for edit in goalEdits {
            let trimmedTitle = edit.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDetails = edit.details.trimmingCharacters(in: .whitespacesAndNewlines)

            if let goal = edit.existingGoal {
                guard !trimmedTitle.isEmpty else { continue }
                if trimmedTitle != edit.originalTitle {
                    goal.title = trimmedTitle
                }
                if trimmedDetails != edit.originalDetails {
                    goal.details = trimmedDetails
                }
                if edit.status != edit.originalStatus {
                    let entry = GoalStatusEntry(
                        oldStatus: edit.originalStatus,
                        newStatus: edit.status,
                        source: .manual,
                        therapistNote: "Updated from client editor"
                    )
                    modelContext.insert(entry)
                    entry.goal = goal
                    goal.currentStatusRaw = edit.status.rawValue
                }
            } else {
                guard !trimmedTitle.isEmpty else { continue }
                let goal = Goal(title: trimmedTitle, details: trimmedDetails, status: edit.status)
                modelContext.insert(goal)
                goal.client = effectiveClient
                let entry = GoalStatusEntry(
                    oldStatus: nil,
                    newStatus: edit.status,
                    source: .manual,
                    therapistNote: "Goal created"
                )
                modelContext.insert(entry)
                entry.goal = goal
            }
        }

        for goal in deletedExistingGoals {
            modelContext.delete(goal)
        }

        try? modelContext.save()
        isPresented = false
    }
}

import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let client: Client?
    let editingGoal: Goal?

    @State private var title: String
    @State private var details: String
    @State private var initialStatus: GoalStatus

    init(isPresented: Binding<Bool>, client: Client? = nil, editing goal: Goal? = nil) {
        self._isPresented = isPresented
        self.client = client
        self.editingGoal = goal
        _title = State(initialValue: goal?.title ?? "")
        _details = State(initialValue: goal?.details ?? "")
        _initialStatus = State(initialValue: goal?.currentStatus ?? .notStarted)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    private var navTitle: String {
        editingGoal == nil ? "New Goal" : "Edit Goal"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Improve fine motor coordination", text: $title, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                } header: {
                    Text("Details (optional)")
                } footer: {
                    Text("Add context, baseline, or measurement criteria.")
                }

                if editingGoal == nil {
                    Section("Starting Status") {
                        Picker("Status", selection: $initialStatus) {
                            ForEach(GoalStatus.allCases) { status in
                                Label(status.rawValue, systemImage: status.systemImage).tag(status)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            }
            .navigationTitle(navTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if let goal = editingGoal {
            goal.title = trimmedTitle
            goal.details = trimmedDetails
        } else {
            let goal = Goal(title: trimmedTitle, details: trimmedDetails, status: initialStatus)
            modelContext.insert(goal)
            goal.client = client
            let entry = GoalStatusEntry(
                oldStatus: nil,
                newStatus: initialStatus,
                source: .manual,
                therapistNote: "Goal created"
            )
            modelContext.insert(entry)
            entry.goal = goal
        }
        try? modelContext.save()
        isPresented = false
    }
}

import SwiftUI
import SwiftData

struct GoalStatusChangeSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    @State private var newStatus: GoalStatus
    @State private var note: String = ""

    init(isPresented: Binding<Bool>, goal: Goal) {
        self._isPresented = isPresented
        self.goal = goal
        _newStatus = State(initialValue: goal.currentStatus)
    }

    private var canSave: Bool {
        newStatus != goal.currentStatus
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Status") {
                    Picker("Status", selection: $newStatus) {
                        ForEach(GoalStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.systemImage).tag(status)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    TextEditor(text: $note)
                        .frame(minHeight: 60)
                } header: {
                    Text("Note (optional)")
                } footer: {
                    Text("Add context for this change. Visible in the goal's history.")
                }
            }
            .navigationTitle("Change Status")
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
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = GoalStatusEntry(
            oldStatus: goal.currentStatus,
            newStatus: newStatus,
            source: .manual,
            therapistNote: trimmedNote.isEmpty ? nil : trimmedNote
        )
        modelContext.insert(entry)
        entry.goal = goal
        goal.currentStatusRaw = newStatus.rawValue
        try? modelContext.save()
        isPresented = false
    }
}

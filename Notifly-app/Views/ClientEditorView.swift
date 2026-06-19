import SwiftUI
import SwiftData

struct ClientEditorView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editingClient: Client?
    @State private var firstName: String
    @State private var lastName: String

    init(isPresented: Binding<Bool>, editing client: Client? = nil) {
        self._isPresented = isPresented
        self.editingClient = client
        _firstName = State(initialValue: client?.firstName ?? "")
        _lastName = State(initialValue: client?.lastName ?? "")
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

    private func save() {
        if let client = editingClient {
            client.firstName = trimmedFirst
            client.lastName = trimmedLast
        } else {
            let client = Client(firstName: trimmedFirst, lastName: trimmedLast)
            modelContext.insert(client)
        }
        try? modelContext.save()
        isPresented = false
    }
}

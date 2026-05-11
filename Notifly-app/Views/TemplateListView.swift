import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteTemplate.name) private var templates: [NoteTemplate]
    @State private var showEditor = false
    @State private var editingTemplate: NoteTemplate?
    @State private var searchText = ""

    private var filteredTemplates: [NoteTemplate] {
        if searchText.isEmpty { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("No Templates", systemImage: "doc.badge.plus")
                } description: {
                    Text("Create a custom template to define your own note sections.")
                } actions: {
                    Button("Create Template") {
                        showEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(filteredTemplates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if template.isTableFormat {
                                        Text("Multi-Goal")
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.fill.tertiary)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(template.sectionTitles.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteTemplates)
                }
            }
        }
        .navigationTitle("Templates")
        .searchable(text: $searchText, prompt: "Search templates")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !templates.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            TemplateEditorView()
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(existingTemplate: template)
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredTemplates[index])
            }
        }
    }
}

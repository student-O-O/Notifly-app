import Foundation
import SwiftData

@Model
final class NoteTemplate {
    var id: UUID
    var name: String
    var sectionTitles: [String]
    var promptInstructions: String
    var dateCreated: Date
    var isTableFormat: Bool

    init(name: String, sectionTitles: [String], promptInstructions: String = "", isTableFormat: Bool = false) {
        self.id = UUID()
        self.name = name
        self.sectionTitles = sectionTitles
        self.promptInstructions = promptInstructions
        self.dateCreated = Date()
        self.isTableFormat = isTableFormat
    }
}

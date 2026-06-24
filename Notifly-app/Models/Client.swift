import Foundation
import SwiftData

@Model
final class Client {
    var id: UUID
    var firstName: String
    var lastName: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \SessionNote.client)
    var sessionNotes: [SessionNote] = []

    @Relationship(deleteRule: .cascade, inverse: \Goal.client)
    var goals: [Goal] = []

    init(firstName: String, lastName: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.createdAt = createdAt
    }

    var displayName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var initials: String {
        let f = firstName.trimmingCharacters(in: .whitespaces).first.map { String($0) } ?? ""
        let l = lastName.trimmingCharacters(in: .whitespaces).first.map { String($0) } ?? ""
        let result = (f + l).uppercased()
        return result.isEmpty ? "?" : result
    }

    var lastSessionDate: Date? {
        sessionNotes.map(\.date).max()
    }

    var activeGoals: [Goal] {
        goals.filter { !$0.archived }.sorted { $0.createdAt < $1.createdAt }
    }

    var archivedGoals: [Goal] {
        goals.filter { $0.archived }.sorted { $0.createdAt > $1.createdAt }
    }

    var notesNewestFirst: [SessionNote] {
        sessionNotes.sorted { $0.date > $1.date }
    }
}

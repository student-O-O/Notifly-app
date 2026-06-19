import Foundation
import SwiftData

@Model
final class Client {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \SessionNote.client)
    var sessionNotes: [SessionNote] = []

    init(name: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
    }

    var initials: String {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        let letters = words.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }

    var lastSessionDate: Date? {
        sessionNotes.map(\.date).max()
    }
}

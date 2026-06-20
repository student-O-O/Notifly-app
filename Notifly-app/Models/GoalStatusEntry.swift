import Foundation
import SwiftData

@Model
final class GoalStatusEntry {
    var id: UUID
    var timestamp: Date
    var oldStatusRaw: String?
    var newStatusRaw: String
    var sourceRaw: String
    var sourceNoteID: UUID?
    var evidenceQuote: String?
    var therapistNote: String?
    var goal: Goal?

    init(
        oldStatus: GoalStatus?,
        newStatus: GoalStatus,
        source: GoalStatusSource,
        sourceNoteID: UUID? = nil,
        evidenceQuote: String? = nil,
        therapistNote: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.oldStatusRaw = oldStatus?.rawValue
        self.newStatusRaw = newStatus.rawValue
        self.sourceRaw = source.rawValue
        self.sourceNoteID = sourceNoteID
        self.evidenceQuote = evidenceQuote
        self.therapistNote = therapistNote
    }

    var oldStatus: GoalStatus? {
        oldStatusRaw.flatMap { GoalStatus(rawValue: $0) }
    }

    var newStatus: GoalStatus {
        GoalStatus(rawValue: newStatusRaw) ?? .notStarted
    }

    var source: GoalStatusSource {
        GoalStatusSource(rawValue: sourceRaw) ?? .manual
    }
}

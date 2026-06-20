import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var details: String
    var createdAt: Date
    var archived: Bool
    var currentStatusRaw: String
    var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \GoalStatusEntry.goal)
    var history: [GoalStatusEntry] = []

    init(
        title: String,
        details: String = "",
        status: GoalStatus = .notStarted,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.archived = false
        self.currentStatusRaw = status.rawValue
    }

    var currentStatus: GoalStatus {
        GoalStatus(rawValue: currentStatusRaw) ?? .notStarted
    }

    var sortedHistory: [GoalStatusEntry] {
        history.sorted { $0.timestamp > $1.timestamp }
    }

    var startedDate: Date? {
        history
            .filter { $0.newStatus == .inProgress }
            .map(\.timestamp)
            .min()
    }

    var achievedDate: Date? {
        guard currentStatus == .achieved else { return nil }
        return history
            .filter { $0.newStatus == .achieved }
            .map(\.timestamp)
            .max()
    }
}

import Foundation

enum GoalStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case achieved = "Achieved"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .achieved: return "checkmark.seal.fill"
        }
    }
}

enum GoalStatusSource: String, Codable {
    case manual
    case acceptedSuggestion = "accepted_suggestion"
    case dismissedSuggestion = "dismissed_suggestion"
    case edited
}

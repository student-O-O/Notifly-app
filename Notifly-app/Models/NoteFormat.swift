import Foundation

enum NoteFormat: String, Codable, CaseIterable, Identifiable {
    case soap = "SOAP"
    case dap = "DAP"

    var id: String { rawValue }

    var sectionTitles: [String] {
        switch self {
        case .soap:
            return ["Subjective", "Objective", "Assessment", "Plan", "Goals Addressed", "Time Spent", "Interventions Used"]
        case .dap:
            return ["Data", "Assessment", "Plan", "Goals Addressed", "Time Spent", "Interventions Used"]
        }
    }
}

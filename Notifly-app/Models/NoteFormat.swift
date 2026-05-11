import Foundation

enum NoteFormat: String, Codable, CaseIterable, Identifiable {
    case soap = "SOAP"
    case dap = "DAP"
    case custom = "Custom"

    var id: String { rawValue }

    static var builtInFormats: [NoteFormat] {
        [.soap, .dap]
    }

    var sectionTitles: [String] {
        switch self {
        case .soap:
            return ["Subjective", "Objective", "Assessment", "Plan", "Goals Addressed", "Time Spent", "Interventions Used"]
        case .dap:
            return ["Data", "Assessment", "Plan", "Goals Addressed", "Time Spent", "Interventions Used"]
        case .custom:
            return []
        }
    }
}

import Foundation

enum NoteTone: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case clinical = "Clinical"
    case clientFriendly = "Client-Friendly"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .standard:
            return "Balanced details and professional. Third person, factual."
        case .clinical:
            return "Formal clinical language with objective observations."
        case .clientFriendly:
            return "Plain English, positive framing and encouraging. Includes relevant details for family."
        }
    }

    var promptText: String {
        switch self {
        case .standard:
            return "Third person, past tense. Favour specific sequences and direct evidence over summary labels. Retain all verbatim quotes and measurable details."
        case .clinical:
            return "Write in third person. Use professional clinical language. Reference functional deficits and observations objectively and be detailed in the report output."
        case .clientFriendly:
            return "Use plain English. Avoid clinical jargon. Frame goals positively around what the client will achieve. Keep sentences short and encouraging."
        }
    }
}

enum NoteFormat: String, Codable, CaseIterable, Identifiable {
    case soap = "SOAP"
    case dap = "DAP"
    case goalFocused = "Goal-Focused"

    var id: String { rawValue }

    var sectionTitles: [String] {
        switch self {
        case .soap:
            return ["Subjective", "Objective", "Assessment", "Plan", "Goals Addressed", "Time Spent", "Interventions Used"]
        case .dap:
            return ["Data", "Assessment", "Plan", "Goals Addressed", "Time Spent", "Interventions Used"]
        case .goalFocused:
            return ["Session Observations", "Goals"]
        }
    }
}

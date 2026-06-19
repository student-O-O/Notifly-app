import Foundation

enum NoteTone: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case clinical = "Clinical"
    case clientFriendly = "Client-Friendly"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .standard:
            return "Concise clinical summary. Third person, factual, condensed."
        case .clinical:
            return "Formal clinical language with detailed objective observations."
        case .clientFriendly:
            return "Plain English, positive framing and encouraging. Includes relevant details for family."
        }
    }

    /// Injected into the session instructions as the WRITING STYLE block.
    var promptText: String {
        switch self {
        case .standard:
            return "Write concise clinical prose in third person, past tense. Condense filler, false starts, and conversational language aggressively — the note should read much tighter than the transcript — but never at the cost of a measurable detail (duration, frequency, level of assistance) or a clinically meaningful quote."
        case .clinical:
            return "Write in third person, past tense, using formal professional clinical language. Reference functional deficits and observations objectively. Retain measurable detail and specific evidence, but synthesize the clinician's wording into clinical prose rather than transcribing it verbatim."
        case .clientFriendly:
            return "Write in plain English a client or family member can understand. Avoid clinical jargon. Frame goals positively around what the client will achieve. Keep sentences short and encouraging. Summarize — do not quote conversational chatter — but keep the concrete details that show progress (counts, durations, level of help needed)."
        }
    }
}

enum NoteFormat: String, Codable, CaseIterable, Identifiable {
    case soap = "SOAP"
    case dap = "DAP"
    case goalFocused = "Goal-Focused"

    var id: String { rawValue }
}

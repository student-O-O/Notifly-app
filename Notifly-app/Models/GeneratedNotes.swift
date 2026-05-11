import FoundationModels

@Generable(description: "A SOAP clinical note for occupational therapy")
struct SOAPNote {
    @Guide(description: "Subjective: Client's self-reported symptoms, concerns, and feelings")
    var subjective: String

    @Guide(description: "Objective: Observable, measurable findings from the session")
    var objective: String

    @Guide(description: "Assessment: Clinical interpretation of subjective and objective data")
    var assessment: String

    @Guide(description: "Plan: Treatment plan, goals, and next steps")
    var plan: String

    @Guide(description: "Goals addressed during this session")
    var goalsAddressed: String

    @Guide(description: "Approximate time spent in minutes")
    var timeSpent: String

    @Guide(description: "Therapeutic interventions and techniques used")
    var interventionsUsed: String
}

@Generable(description: "A DAP clinical note for occupational therapy")
struct DAPNote {
    @Guide(description: "Data: Objective and subjective information from the session")
    var data: String

    @Guide(description: "Assessment: Clinical interpretation and analysis")
    var assessment: String

    @Guide(description: "Plan: Treatment plan, goals, and next steps")
    var plan: String

    @Guide(description: "Goals addressed during this session")
    var goalsAddressed: String

    @Guide(description: "Approximate time spent in minutes")
    var timeSpent: String

    @Guide(description: "Therapeutic interventions and techniques used")
    var interventionsUsed: String
}

@Generable(description: "A single section of a clinical note")
struct GeneratedSection {
    @Guide(description: "The exact section title as specified in the prompt")
    var title: String

    @Guide(description: "The clinical content for this section")
    var content: String
}

@Generable(description: "A clinical note with custom sections")
struct CustomGeneratedNote {
    @Guide(description: "The sections of the note, one for each section title specified")
    var sections: [GeneratedSection]
}

@Generable(description: "A single named field within a goal entry, containing real content extracted from a transcript")
struct GeneratedGoalField {
    @Guide(description: "The field name, matching exactly one of the specified field names")
    var fieldName: String

    @Guide(description: "Real clinical content extracted from the transcript for this field. Must never be the field name itself.")
    var content: String
}

@Generable(description: "One goal or topic entry extracted from a therapy session transcript")
struct GeneratedGoalEntry {
    @Guide(description: "All fields for this goal, one per field name specified. Each must contain real transcript content.")
    var fields: [GeneratedGoalField]
}

@Generable(description: "All goals extracted from a therapy session transcript. Each distinct goal discussed becomes its own entry.")
struct GeneratedGoalEntries {
    @Guide(description: "One entry per distinct goal or topic found in the transcript. Must have at least one entry.")
    var entries: [GeneratedGoalEntry]
}

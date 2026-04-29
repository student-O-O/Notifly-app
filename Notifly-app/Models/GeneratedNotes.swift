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

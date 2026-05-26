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

@Generable(description: "A single goal addressed during the session, including activities performed, observed client response, progress against prior sessions, and clinician-proposed next steps.")
struct GeneratedGoal {

    @Guide(description: "The goal statement, corrected for speech recognition errors. Preserve measurable criteria verbatim.")
    var goal: String

    @Guide(description: "Therapeutic tasks performed by client. NEVER describe how the client performed - that belongs in Observations.")
    var activities: String

    @Guide(description: """
        Past-tense sequence of what occurred. Minimum 3 sentences. Structure: trigger first \
        (what the OT or peer said/did), then the client's response. \
        1. Identify the speaker before every quote — never assign a quote without naming who said it. \
        2. Reproduce client quotes verbatim in single quotes — never paraphrase. \
        3. Include every measurable detail: duration, prompts required, frequency, independence level. \
        4. Write specific observable behaviour, not interpretive labels \
            ('client turned the paper over', not 'client showed frustration'). \
        5. No future-tense content.
        """)
    var observations: String

    @Guide(description: "Third-person imperative strategies the clinician explicitly proposed for next session (e.g. 'Encourage client to...'). Trigger phrases: 'next time', 'I will try', 'going forward'. Never use first person. Leave empty if no proposal was made. DO NOT invent.")
    var nextSteps: String
}

@Generable(description: "A goal-focused clinical note capturing session-level context and a structured breakdown of each goal addressed.")
struct GoalFocusedNote {

    @Guide(description: "A specific transcript-grounded observation spanning the whole session (overall affect, energy, demeanour). Leave empty if you cannot cite specific evidence. DO NOT fill with generic engagement statements like 'client was engaged throughout'.")
    var sessionObservations: String

    @Guide(description: "Each distinct goal addressed during the session. Include a goal only if an activity was performed against it. Do not duplicate or pad.")
    var goals: [GeneratedGoal]
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

extension GoalFocusedNote {
    static let exampleGoalFocusedNote = GoalFocusedNote(
        sessionObservations: "Client presented as alert and focused throughout the 45-minute session.",
        goals: [
            GeneratedGoal(
            goal: "Improve pincer grasp strength for school readiness.",
            activities: "Bead threading with graded bead sizes; tweezer-based pom-pom transfer.",
            observations: "Client threaded 8 of 10 large beads independently and 4 of 10 small beads with verbal prompts. Maintained pincer grasp for the full 3-minute tweezer task — an improvement from the 1-minute baseline reported last week.",
            nextSteps: "Introduce paper-tearing along curved lines to build on tweezer-strength gains."
            ),
            GeneratedGoal(
            goal: "Increase seated tolerance to 15 minutes during table-top tasks.",
            activities: "Tabletop puzzle activity.",
            observations: "Client maintained seated position for 12 minutes before requesting a 90-second break, then returned independently and completed the task.",
            nextSteps: ""
          )
        ]
    )
}

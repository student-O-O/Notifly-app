import FoundationModels

// MARK: - Public result types
//
// These are assembled in NoteGenerationService from one or more smaller
// generation passes (see below) — they are no longer decoded directly
// from a single model response.

struct SOAPNote {
    var hasSufficientContent: Bool
    var insufficientContentReason: String
    var subjective: String
    var objective: String
    var assessment: String
    var plan: String
    var goalsAddressed: String
    var timeSpent: String
    var interventionsUsed: String
}

struct DAPNote {
    var hasSufficientContent: Bool
    var insufficientContentReason: String
    var data: String
    var assessment: String
    var plan: String
    var goalsAddressed: String
    var timeSpent: String
    var interventionsUsed: String
}

struct GeneratedGoal {
    var goal: String
    var activities: String
    var observations: String
    var nextSteps: String
}

struct GoalFocusedNote {
    var hasSufficientContent: Bool
    var insufficientContentReason: String
    var sessionObservations: String
    var goals: [GeneratedGoal]
}

// MARK: - Generation-pass types
//
// Each of these is what a single, narrowly-scoped LanguageModelSession call
// actually produces. Keeping each pass's schema small and single-purpose
// (facts vs. interpretation, goal-listing vs. goal-detail) is what makes
// on-device generation reliable — a small model following one instruction
// set for a handful of fields is far more consistent than one following a
// dozen rules across nine fields in a single call.

@Generable(description: "The factual portion of a SOAP note for an allied health session: what was reported and observed, drafted strictly from the session transcript.")
struct SOAPFactualPart {
    @Guide(description: """
        Set this to true ONLY if the transcript contains substantive clinical content from an actual \
        therapy session: described activities, observations of client behaviour, measurable performance, \
        clinical interpretation, or stated plans. \
        Set this to FALSE if the transcript is: a test recording, small talk, meta-commentary about \
        using the app or seeing how it works, an empty/near-empty recording, or anything else that \
        is not a real clinical session. When false, leave ALL other fields empty — do NOT invent \
        clinical content to fill the schema.
        """)
    var hasSufficientContent: Bool

    @Guide(description: "If hasSufficientContent is false, briefly state why (e.g. 'transcript is a test recording, no clinical content'). Otherwise leave empty.")
    var insufficientContentReason: String

    @Guide(description: """
        Subjective: what the client or their caregiver reported — symptoms, feelings, pain, concerns, events outside the session. \
        Attribute quotes to the correct speaker. \
        NEVER include the clinician's own observations here. \
        Leave empty if nothing was reported.
        """)
    var subjective: String

    @Guide(description: """
        Objective: observable, measurable findings from the session — activities performed and the client's measured performance. \
        Preserve counts, durations, distances, prompt levels, and assistance levels exactly as stated. \
        Describe specific observable behaviour, not interpretive labels ('client turned the paper over', not 'client showed frustration'). \
        No interpretation here.
        """)
    var objective: String

    @Guide(description: "Goals explicitly worked on during this session, as stated by the clinician. Leave empty if none were named.")
    var goalsAddressed: String

    @Guide(description: "Session duration in minutes, ONLY if explicitly stated in the transcript (e.g. '45 minutes'). Leave empty if not mentioned. NEVER estimate.")
    var timeSpent: String

    @Guide(description: "Therapeutic interventions and techniques actually used in the session, as described by the clinician. Leave empty if none were described.")
    var interventionsUsed: String
}

@Generable(description: "The interpretive portion of a SOAP note for an allied health session: the clinician's own stated assessment and plan, drafted strictly from the session transcript.")
struct SOAPInterpretivePart {
    @Guide(description: """
        Assessment: the clinician's stated interpretation of progress, barriers, and the client's response to intervention. \
        Synthesize only conclusions the clinician actually voiced. \
        Never introduce new diagnoses or conclusions. Leave empty if the clinician gave no interpretation.
        """)
    var assessment: String

    @Guide(description: """
        Plan: next steps the clinician explicitly stated — next-session focus, home program, referrals, frequency changes. \
        Trigger phrases: 'next time', 'I will try', 'going forward'. \
        Leave empty if no plan was stated. DO NOT invent next steps.
        """)
    var plan: String
}

@Generable(description: "The factual portion of a DAP note for an allied health session: what was reported and observed, drafted strictly from the session transcript.")
struct DAPFactualPart {
    @Guide(description: """
        Set this to true ONLY if the transcript contains substantive clinical content from an actual \
        therapy session: described activities, observations of client behaviour, measurable performance, \
        clinical interpretation, or stated plans. \
        Set this to FALSE if the transcript is: a test recording, small talk, meta-commentary about \
        using the app or seeing how it works, an empty/near-empty recording, or anything else that \
        is not a real clinical session. When false, leave ALL other fields empty — do NOT invent \
        clinical content to fill the schema.
        """)
    var hasSufficientContent: Bool

    @Guide(description: "If hasSufficientContent is false, briefly state why (e.g. 'transcript is a test recording, no clinical content'). Otherwise leave empty.")
    var insufficientContentReason: String

    @Guide(description: """
        Data: all factual information from the session — what the client or caregiver reported (with quotes attributed to the correct speaker), \
        activities performed, and the client's measured performance. \
        Preserve counts, durations, prompt levels, and assistance levels exactly as stated. \
        Facts only — no interpretation.
        """)
    var data: String

    @Guide(description: "Goals explicitly worked on during this session, as stated by the clinician. Leave empty if none were named.")
    var goalsAddressed: String

    @Guide(description: "Session duration in minutes, ONLY if explicitly stated in the transcript (e.g. '45 minutes'). Leave empty if not mentioned. NEVER estimate.")
    var timeSpent: String

    @Guide(description: "Therapeutic interventions and techniques actually used in the session, as described by the clinician. Leave empty if none were described.")
    var interventionsUsed: String
}

typealias DAPInterpretivePart = SOAPInterpretivePart

@Generable(description: "Pass 1 of goal-focused note generation: session-level observations and each distinct goal addressed, with only the activities performed toward each goal. Observations and next steps are filled in later, per goal.")
struct GoalListing {
    @Guide(description: """
        Set this to true ONLY if the transcript contains substantive clinical content from an actual \
        therapy session: described activities, observations of client behaviour, measurable performance, \
        or goals worked on. \
        Set this to FALSE if the transcript is: a test recording, small talk, meta-commentary about \
        using the app or seeing how it works, an empty/near-empty recording, or anything else that \
        is not a real clinical session. When false, leave sessionObservations empty and return an \
        empty goals array — do NOT invent goals or activities to fill the schema.
        """)
    var hasSufficientContent: Bool

    @Guide(description: "If hasSufficientContent is false, briefly state why (e.g. 'transcript is a test recording, no clinical content'). Otherwise leave empty.")
    var insufficientContentReason: String

    @Guide(description: "A specific transcript-grounded observation spanning the whole session (overall affect, energy, demeanour). Leave empty if you cannot cite specific evidence. DO NOT fill with generic engagement statements like 'client was engaged throughout'.")
    var sessionObservations: String

    @Guide(description: """
        Each distinct goal addressed during the session, with only the activities performed toward it. \
        Include a goal only if an activity was actually performed against it. Do not duplicate or pad. \
        Every activity in the transcript belongs to exactly one goal — do not list the same activity \
        under more than one goal.
        """)
    var goals: [GoalStub]
}

@Generable(description: "A single goal identified in the transcript, with only the activities performed toward it. Observations and next steps are not filled in yet.")
struct GoalStub {
    @Guide(description: "The goal statement, corrected for speech recognition errors. Preserve measurable criteria verbatim.")
    var goal: String

    @Guide(description: "Therapeutic tasks performed by the client toward this goal. NEVER describe how the client performed - that belongs to a later pass. eg. 'Discussion with mum', 'Played with toys', 'Fine motor task lego' etc.")
    var activities: String
}

@Generable(description: "Pass 2 of goal-focused note generation: the observations and next steps for ONE specific goal, scoped strictly to that goal's activities.")
struct GoalDetail {
    @Guide(description: """
        Past-tense clinical summary of what occurred DURING THE ACTIVITIES listed for this goal — and \
        ONLY those activities. Do not describe evidence that belongs to a different goal. \
        Structure: trigger first (what the clinician or peer said/did), then the client's response. \
        1. Preserve measurable details (duration, prompts required, frequency, independence level) verbatim. \
        2. Write specific observable behaviour, not interpretive labels \
            ('client turned the paper over', not 'client showed frustration'). \
        3. No future-tense content. \
        Length is whatever it takes to capture every measurable observation for this goal — no padding, \
        no compression for its own sake.
        """)
    var observations: String

    @Guide(description: "Third-person imperative strategies the clinician explicitly proposed for next session (e.g. 'Encourage client to...'). Trigger phrases: 'next time', 'I will try', 'going forward'. Never use first person. Leave empty if no proposal was made for this goal. DO NOT invent.")
    var nextSteps: String
}

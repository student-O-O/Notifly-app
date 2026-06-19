import FoundationModels

@Generable(description: "A SOAP clinical note for an allied health session, drafted strictly from the session transcript.")
struct SOAPNote {
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
        No interpretation here — that belongs in Assessment.
        """)
    var objective: String

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

    @Guide(description: "Goals explicitly worked on during this session, as stated by the clinician. Leave empty if none were named.")
    var goalsAddressed: String

    @Guide(description: "Session duration in minutes, ONLY if explicitly stated in the transcript (e.g. '45 minutes'). Leave empty if not mentioned. NEVER estimate.")
    var timeSpent: String

    @Guide(description: "Therapeutic interventions and techniques actually used in the session, as described by the clinician. Leave empty if none were described.")
    var interventionsUsed: String
}

@Generable(description: "A DAP clinical note for an allied health session, drafted strictly from the session transcript.")
struct DAPNote {
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

    @Guide(description: "Goals explicitly worked on during this session, as stated by the clinician. Leave empty if none were named.")
    var goalsAddressed: String

    @Guide(description: "Session duration in minutes, ONLY if explicitly stated in the transcript (e.g. '45 minutes'). Leave empty if not mentioned. NEVER estimate.")
    var timeSpent: String

    @Guide(description: "Therapeutic interventions and techniques actually used in the session, as described by the clinician. Leave empty if none were described.")
    var interventionsUsed: String
}

@Generable(description: "A single goal addressed during the session, including activities performed, observed client response, progress against prior sessions, and clinician-proposed next steps.")
struct GeneratedGoal {

    @Guide(description: "The goal statement, corrected for speech recognition errors. Preserve measurable criteria verbatim.")
    var goal: String

    @Guide(description: "Therapeutic tasks performed by client. NEVER describe how the client performed - that belongs in Observations. eg. 'Discussion with mum', 'Played with toys','Fine motor task lego' etc. ")
    var activities: String

    @Guide(description: """
        Past-tense clinical summary of what occurred DURING THE ACTIVITIES listed in this goal's \
        'activities' field — and ONLY those activities. \
        SCOPE: every sentence must describe behaviour observed while the client was doing one of \
        this goal's activities. If a piece of transcript evidence belongs to a different goal's \
        activities, it MUST NOT appear here. Do not reuse evidence already attributed to another goal. \
        Structure: trigger first (what the clinician or peer said/did), then the client's response. \
        1. Preserve measurable details (duration, prompts required, frequency, independence level) verbatim. \
        2. Write specific observable behaviour, not interpretive labels \
            ('client turned the paper over', not 'client showed frustration'). \
        3. No future-tense content. \
        Length is whatever it takes to capture every measurable observation for THIS goal only — \
        no padding, no compression for its own sake, no borrowing from other goals.
        """)
    var observations: String

    @Guide(description: "Third-person imperative strategies the clinician explicitly proposed for next session (e.g. 'Encourage client to...'). Trigger phrases: 'next time', 'I will try', 'going forward'. Never use first person. Leave empty if no proposal was made. DO NOT invent.")
    var nextSteps: String
}

@Generable(description: "A goal-focused clinical note capturing session-level context and a structured breakdown of each goal addressed.")
struct GoalFocusedNote {

    @Guide(description: """
        Set this to true ONLY if the transcript contains substantive clinical content from an actual \
        therapy session: described activities, observations of client behaviour, measurable performance, \
        or goals worked on. \
        Set this to FALSE if the transcript is: a test recording, small talk, meta-commentary about \
        using the app or seeing how it works, an empty/near-empty recording, or anything else that \
        is not a real clinical session. When false, leave sessionObservations empty and return an \
        empty goals array — do NOT invent goals, activities, or observations to fill the schema.
        """)
    var hasSufficientContent: Bool

    @Guide(description: "If hasSufficientContent is false, briefly state why (e.g. 'transcript is a test recording, no clinical content'). Otherwise leave empty.")
    var insufficientContentReason: String

    @Guide(description: "A specific transcript-grounded observation spanning the whole session (overall affect, energy, demeanour). Leave empty if you cannot cite specific evidence. DO NOT fill with generic engagement statements like 'client was engaged throughout'.")
    var sessionObservations: String

    @Guide(description: """
        Each distinct goal addressed during the session. Include a goal only if an activity was \
        performed against it. Do not duplicate or pad. \
        IMPORTANT: each goal's activities, observations, and nextSteps must describe ONLY the work \
        done toward that specific goal. Do not share evidence across goals — every measurable \
        observation in the transcript belongs to exactly one goal.
        """)
    var goals: [GeneratedGoal]
}


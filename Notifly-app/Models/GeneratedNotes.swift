import FoundationModels

// MARK: - Public result types
//
// Assembled in NoteGenerationService from several passes.

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
    /// Session content that isn't about any of the client's documented goals.
    /// Left for the clinician to write when there is no client profile to
    /// diff the session against.
    var sessionObservations: String
    var goals: [GeneratedGoal]
}

// MARK: - Generation-pass types
//
// Guides follow Apple's guidance for the on-device model: a short description
// of what the field is, an explicit length, the condition under which it is
// empty, and at most one small example. Cross-field rules live once, in the
// pass instructions; deterministic cleanups live in code. Stacking DO NOTs
// here proved counterproductive — several named the exact failure they were
// meant to prevent, and the model reproduced it.

@Generable(description: "The facts of a therapy session: what was reported, done and seen.")
struct SOAPFactualPart {
    @Guide(description: "True if this is a real therapy session with clinical content. False for a test recording, small talk, or chatter about the app.")
    var hasSufficientContent: Bool

    @Guide(description: "One short phrase saying why, only when hasSufficientContent is false.")
    var insufficientContentReason: String?

    @Guide(description: "What the client or their carer reported about how things are going. 1-4 sentences. Empty if nothing was reported.")
    var subjective: String

    @Guide(description: "The activities done and the behaviour seen, with numbers, prompt levels and assistance levels kept as spoken. 2-6 sentences.")
    var objective: String

    @Guide(description: "The goals the clinician said were worked on. Empty if none were named.")
    var goalsAddressed: String

    @Guide(description: "The session length the clinician stated, such as '45 minutes'. Empty if they did not state one.")
    var timeSpent: String

    @Guide(description: "Techniques the clinician described using. Empty if none were described.")
    var interventionsUsed: String
}

@Generable(description: "A clinician's own conclusions and plan for a therapy session.")
struct SOAPInterpretivePart {
    @Guide(description: "The clinician's stated view of progress, barriers and the client's response. 1-4 sentences. Empty if they gave none.")
    var assessment: String

    @Guide(description: "The next steps the clinician stated, written in the third person. 1-4 sentences. Empty if no plan was stated.")
    var plan: String
}

@Generable(description: "The facts of a therapy session for a DAP note.")
struct DAPFactualPart {
    @Guide(description: "True if this is a real therapy session with clinical content. False for a test recording, small talk, or chatter about the app.")
    var hasSufficientContent: Bool

    @Guide(description: "One short phrase saying why, only when hasSufficientContent is false.")
    var insufficientContentReason: String?

    @Guide(description: "Everything factual — what was reported, what was done, what was seen — with numbers, prompt levels and assistance levels kept as spoken. 3-8 sentences.")
    var data: String

    @Guide(description: "The goals the clinician said were worked on. Empty if none were named.")
    var goalsAddressed: String

    @Guide(description: "The session length the clinician stated, such as '45 minutes'. Empty if they did not state one.")
    var timeSpent: String

    @Guide(description: "Techniques the clinician described using. Empty if none were described.")
    var interventionsUsed: String
}

typealias DAPInterpretivePart = SOAPInterpretivePart

// MARK: - Goal-focused: client has documented goals
//
// The client's profile is the source of truth for what goals exist — the
// model never names or invents a goal here, it only reports whether each
// known goal was addressed today.

@Generable(description: "Whether today's transcript is a real therapy session with clinical content.")
struct SessionGate {
    @Guide(description: "True if this is a real therapy session with clinical content. False for a test recording, small talk, or chatter about the app.")
    var hasSufficientContent: Bool

    @Guide(description: "One short phrase saying why, only when hasSufficientContent is false.")
    var insufficientContentReason: String?
}

/// Locates each documented goal in the transcript so the per-goal write-up
/// pass can be given a narrowed window instead of the whole session — the
/// goal never has to be discovered or named here, only found, since the
/// title is already known.
@Generable(description: "Where each of the client's documented goals begins in today's session, if addressed.")
struct GoalAnchorSet {
    @Guide(description: "One entry for every goal in the CLIENT block below, in the exact same order — including an empty entry for a goal not addressed today.")
    var anchors: [GoalAnchor]
}

@Generable(description: "Where one documented goal's discussion begins in the transcript, if it was addressed today.")
struct GoalAnchor {
    @Guide(description: "The first six words, exactly as spoken, of the sentence where the clinician begins this goal. Empty if this goal was not addressed today, or if there is no clear starting point.")
    var sectionStart: String
}

@Generable(description: "How one of the client's documented goals was addressed in today's session.")
struct GoalWriteUp {
    @Guide(description: "A short phrase naming the tasks done toward this goal today, such as 'Played with trucks' or 'Discussion with mum'. Use your own words rather than quoting the transcript verbatim. Empty if this goal was not addressed today.")
    var activities: String

    @Guide(description: "What happened and how the client responded, written in your own words as past-tense clinical notes, with numbers, prompt levels and assistance levels kept as spoken. Cover every distinct moment the transcript describes for this goal, not just the clearest one. 2-6 sentences. Empty if this goal was not addressed today.")
    var observations: String

    @Guide(description: "What the clinician said to try next session for this goal, written in the third person, including any specific technique or phrasing they proposed. 1-3 sentences. Empty if they proposed nothing for this goal.")
    var nextSteps: String
}

/// Generated after every documented goal has been written up, and grounded on
/// that actual generated text (not just the abstract goal list) so the model
/// has something concrete to diff against instead of re-describing a goal.
@Generable(description: "Session content not already covered by the client's goal write-ups.")
struct LeftoverObservations {
    @Guide(description: "A summary, in your own words, of session content that is NOT already covered by the goal write-ups referenced below — anything general, incidental, or about a goal that isn't documented. 1-4 sentences. Empty if the write-ups already cover everything in the transcript.")
    var text: String
}

// MARK: - Goal-focused: no documented goals (fallback)
//
// Without a client profile to anchor on, goals are discovered freehand from
// the transcript instead.

@Generable(description: "A therapy session split into the goals the clinician worked on during it.")
struct GoalListing {
    @Guide(description: "True if this is a real therapy session with clinical content. False for a test recording, small talk, or chatter about the app.")
    var hasSufficientContent: Bool

    @Guide(description: "One short phrase saying why, only when hasSufficientContent is false.")
    var insufficientContentReason: String?

    @Guide(description: "One entry for each goal worked on during the session, in the order discussed. Most sessions have two to four.")
    var goals: [GoalStub]
}

@Generable(description: "One goal worked on during the session.")
struct GoalStub {
    @Guide(description: "A goal the clinician worked on this session, with speech errors corrected. A plan for next time is not a goal.")
    var goal: String

    @Guide(description: "A short phrase naming the tasks done toward this goal, such as 'Played with trucks' or 'Discussion with mum'. Use your own words rather than quoting the transcript verbatim.")
    var activities: String
}

@Generable(description: "The write-up of one goal, based only on that goal's extract.")
struct GoalDetail {
    @Guide(description: "The extract rewritten in your own words as past-tense clinical notes: what happened and how the client responded, with numbers, prompt levels and assistance levels kept as spoken. 2-5 sentences. Empty if the extract describes nothing that happened.")
    var observations: String

    @Guide(description: "What the clinician said to try next session, written in the third person. 1-3 sentences. Empty if they proposed nothing.")
    var nextSteps: String
}

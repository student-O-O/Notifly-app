import Foundation
import FoundationModels

/// Errors raised during note generation, with messages suitable for
/// showing directly to a clinician in the UI.
enum NoteGenerationError: LocalizedError {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case emptyTranscript
    case transcriptTooLong
    case contentFlagged
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, which is required to generate notes on-device."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings > Apple Intelligence & Siri, then try again."
        case .modelNotReady:
            return "The on-device model is still downloading. Please try again in a few minutes."
        case .emptyTranscript:
            return "The transcript is empty, so there is nothing to convert into a note."
        case .transcriptTooLong:
            return "This transcript is too long for the on-device model. Try recording shorter segments and generating a note for each."
        case .contentFlagged:
            return "The on-device model declined to process this transcript. Review the transcript and try again."
        case .generationFailed(let detail):
            return "Note generation failed: \(detail)"
        }
    }
}

struct NoteGenerationService {

    /// Low temperature: clinical drafting should be faithful to the
    /// transcript, not creative.
    private static let generationOptions = GenerationOptions(temperature: 0.1)

    // MARK: - Public API
    //
    // Each note is assembled from multiple small, single-purpose generation
    // passes rather than one call producing every field at once. A small
    // on-device model follows a short, focused instruction set far more
    // reliably than a long one covering many cross-field rules at once, so
    // splitting "extract the facts" from "interpret the facts" (and, for
    // goal-focused notes, "list the goals" from "detail one goal")
    // meaningfully improves consistency.

    static func generateSOAP(transcript: String, tone: NoteTone = .standard) async throws -> SOAPNote {
        let trimmed = try validate(transcript)

        let factual = try await generate(
            SOAPFactualPart.self,
            transcript: trimmed,
            request: "Extract the factual content of this session as the first pass of a SOAP note.",
            instructions: factualInstructions(tone: tone, formatGuidance: Self.soapFactualGuidance)
        )

        guard factual.hasSufficientContent else {
            return SOAPNote(
                hasSufficientContent: false,
                insufficientContentReason: factual.insufficientContentReason,
                subjective: "", objective: "", assessment: "", plan: "",
                goalsAddressed: "", timeSpent: "", interventionsUsed: ""
            )
        }

        let interpretive = try await generate(
            SOAPInterpretivePart.self,
            transcript: trimmed,
            request: "Extract the clinician's assessment and plan as the second pass of a SOAP note.",
            instructions: interpretiveInstructions(tone: tone)
        )

        return SOAPNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            subjective: factual.subjective,
            objective: factual.objective,
            assessment: interpretive.assessment,
            plan: interpretive.plan,
            goalsAddressed: factual.goalsAddressed,
            timeSpent: factual.timeSpent,
            interventionsUsed: factual.interventionsUsed
        )
    }

    static func generateDAP(transcript: String, tone: NoteTone = .standard) async throws -> DAPNote {
        let trimmed = try validate(transcript)

        let factual = try await generate(
            DAPFactualPart.self,
            transcript: trimmed,
            request: "Extract the factual content of this session as the first pass of a DAP note.",
            instructions: factualInstructions(tone: tone, formatGuidance: Self.dapFactualGuidance)
        )

        guard factual.hasSufficientContent else {
            return DAPNote(
                hasSufficientContent: false,
                insufficientContentReason: factual.insufficientContentReason,
                data: "", assessment: "", plan: "",
                goalsAddressed: "", timeSpent: "", interventionsUsed: ""
            )
        }

        let interpretive = try await generate(
            DAPInterpretivePart.self,
            transcript: trimmed,
            request: "Extract the clinician's assessment and plan as the second pass of a DAP note.",
            instructions: interpretiveInstructions(tone: tone)
        )

        return DAPNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            data: factual.data,
            assessment: interpretive.assessment,
            plan: interpretive.plan,
            goalsAddressed: factual.goalsAddressed,
            timeSpent: factual.timeSpent,
            interventionsUsed: factual.interventionsUsed
        )
    }

    static func generateGoalFocused(transcript: String, tone: NoteTone = .standard) async throws -> GoalFocusedNote {
        let trimmed = try validate(transcript)

        let listing = try await generate(
            GoalListing.self,
            transcript: trimmed,
            request: "Identify the session-level observations and each distinct goal addressed, as the first pass of a goal-focused note.",
            instructions: goalListingInstructions(tone: tone)
        )

        guard listing.hasSufficientContent else {
            return GoalFocusedNote(
                hasSufficientContent: false,
                insufficientContentReason: listing.insufficientContentReason,
                sessionObservations: "",
                goals: []
            )
        }

        guard !listing.goals.isEmpty else {
            return GoalFocusedNote(
                hasSufficientContent: true,
                insufficientContentReason: "",
                sessionObservations: listing.sessionObservations,
                goals: []
            )
        }

        // One call per goal, run sequentially: each pass is told exactly which
        // activities belong to its goal and which belong to the others, so the
        // model doesn't have to self-partition transcript evidence across every
        // goal at once — the failure mode that made goal-focused notes the
        // least reliable format.
        var goals: [GeneratedGoal] = []
        for (index, stub) in listing.goals.enumerated() {
            let otherGoals = listing.goals.enumerated()
                .filter { $0.offset != index }
                .map(\.element)

            let detail = try await generate(
                GoalDetail.self,
                transcript: trimmed,
                request: "Write the observations and next steps for this one goal only: \"\(stub.goal)\".",
                instructions: goalDetailInstructions(tone: tone, targetGoal: stub, otherGoals: otherGoals)
            )

            goals.append(GeneratedGoal(
                goal: stub.goal,
                activities: stub.activities,
                observations: detail.observations,
                nextSteps: detail.nextSteps
            ))
        }

        return GoalFocusedNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            sessionObservations: listing.sessionObservations,
            goals: goals
        )
    }

    // MARK: - Core generation

    private static func validate(_ transcript: String) throws -> String {
        try ensureModelAvailable()
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NoteGenerationError.emptyTranscript }
        return trimmed
    }

    private static func generate<Output: Generable>(
        _ type: Output.Type,
        transcript: String,
        request: String,
        instructions: Instructions
    ) async throws -> Output {
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
            \(request)

            Transcript:
            \(transcript)
            """

        do {
            let response = try await session.respond(to: prompt, generating: Output.self, options: generationOptions)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw map(error)
        }
    }

    /// Verify the on-device foundation model can actually run before we
    /// build a session, so the UI can show an actionable message.
    private static func ensureModelAvailable() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                throw NoteGenerationError.deviceNotEligible
            case .appleIntelligenceNotEnabled:
                throw NoteGenerationError.appleIntelligenceNotEnabled
            case .modelNotReady:
                throw NoteGenerationError.modelNotReady
            @unknown default:
                throw NoteGenerationError.generationFailed("The on-device model is unavailable.")
            }
        }
    }

    private static func map(_ error: LanguageModelSession.GenerationError) -> NoteGenerationError {
        switch error {
        case .exceededContextWindowSize:
            return .transcriptTooLong
        case .guardrailViolation:
            return .contentFlagged
        case .assetsUnavailable:
            return .modelNotReady
        default:
            return .generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Shared instruction fragments

    private static let assistantPreamble = """
        You are a clinical documentation assistant for allied health \
        professionals (occupational therapy, physiotherapy, speech \
        pathology, and similar disciplines). You turn a raw, imperfect \
        speech-to-text transcript of a clinician's post-session dictation \
        into a structured draft note.
        """

    private static let sufficiencyCheckRule = """
        0. SUFFICIENCY CHECK FIRST. Before filling any field, decide whether the \
        transcript actually contains clinical content from a real therapy session. \
        If it is a test recording, small talk, meta-commentary about the app, \
        empty/near-empty, or otherwise not a real clinical session, set \
        hasSufficientContent = false, write a brief reason in \
        insufficientContentReason, and LEAVE EVERY OTHER FIELD EMPTY. \
        Do not invent goals, activities, observations, or plans to fill the \
        schema. Refusing to generate a note is the correct outcome here.
        """

    private static let coreEvidenceRules = """
        EVIDENCE RULES — these override everything else:
        1. Ground every statement in the transcript. Never invent client \
        history, assessment findings, outcomes, goals, or clinical detail \
        the clinician did not say.
        2. If the transcript contains nothing for a section, leave that \
        section empty. An empty section is always better than fabricated \
        or generic filler content.
        3. Never state a goal as achieved or progress as made unless the \
        clinician explicitly says so.
        4. PRESERVE every clinically meaningful detail: measurable data \
        (counts, durations, distances, prompt levels, assistance levels), \
        specific observable behaviour in the clinician's original words, \
        and quotes that carry clinical meaning. Attribute every quote to \
        the correct speaker.
        5. REMOVE everything else: filler words, false starts, \
        self-narration, and conversational chatter. Length is a \
        consequence, never a target — do NOT drop a measurable detail to \
        shorten a section.
        6. Silently correct obvious speech-recognition errors when the \
        intended word is unambiguous (e.g. "pincher grasp" → "pincer \
        grasp"). If the intended word is ambiguous, keep it as transcribed.
        7. You are NOT a diagnostic tool. Your output is a draft for the \
        treating clinician to review, edit, and sign.
        """

    // MARK: - Instructions: factual / interpretive passes (SOAP & DAP)

    private static func factualInstructions(tone: NoteTone, formatGuidance: String) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            This is the FACT-EXTRACTION pass. Pull out what was reported and what \
            was observed. Do not interpret, evaluate progress, or state conclusions \
            — that happens in a separate pass. Just extract and organize facts.

            \(sufficiencyCheckRule)
            \(coreEvidenceRules)

            WRITING STYLE:
            \(tone.promptText)

            FORMAT:
            \(formatGuidance)
            """)
    }

    private static func interpretiveInstructions(tone: NoteTone) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            This is the INTERPRETATION pass. Capture only the clinician's own \
            stated interpretation of progress, barriers, response to intervention, \
            and next steps. The factual details of the session have already been \
            captured in a separate pass — do not restate them here, only \
            synthesize meaning and plans.

            \(coreEvidenceRules)

            WRITING STYLE:
            \(tone.promptText)

            FORMAT:
            \(Self.interpretiveGuidance)
            """)
    }

    private static let soapFactualGuidance = """
        Produce the factual portion of a SOAP note:
        - Subjective: only what the client or their caregiver reported — \
        feelings, pain, concerns, events outside the session. Never the \
        clinician's own observations.
        - Objective: observable, measurable findings — activities performed \
        and the client's measured performance (counts, durations, assistance \
        levels).
        Also extract: goals explicitly worked on, session duration (only if \
        explicitly stated), and interventions/techniques actually used.
        """

    private static let dapFactualGuidance = """
        Produce the factual portion of a DAP note:
        - Data: all factual information from the session — what the client \
        or caregiver reported, activities performed, and measured performance \
        (counts, durations, assistance levels).
        Also extract: goals explicitly worked on, session duration (only if \
        explicitly stated), and interventions/techniques actually used.
        """

    private static let interpretiveGuidance = """
        - Assessment: the clinician's stated interpretation of progress, \
        barriers, and responses. Synthesize only what was said.
        - Plan: explicitly stated next steps — next-session focus, home \
        programs, referrals, frequency changes.
        """

    // MARK: - Instructions: goal-focused listing / detail passes

    private static func goalListingInstructions(tone: NoteTone) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            This is the GOAL-IDENTIFICATION pass. Identify session-level \
            observations and each distinct goal the clinician addressed, along \
            with only the activities performed toward each goal. Do NOT fill in \
            observations or next steps yet — that happens in a later pass, one \
            goal at a time.

            \(sufficiencyCheckRule)
            \(coreEvidenceRules)

            Include a goal only if an activity was actually performed against it \
            during the session. Do not duplicate goals or pad the list. Every \
            activity in the transcript belongs to exactly one goal — do not list \
            the same activity under more than one goal. If the transcript does \
            not mention any goals, return an empty goals array rather than \
            inventing one.

            WRITING STYLE:
            \(tone.promptText)
            """)
    }

    private static func goalDetailInstructions(tone: NoteTone, targetGoal: GoalStub, otherGoals: [GoalStub]) -> Instructions {
        let otherGoalsList = otherGoals.isEmpty
            ? "There are no other goals this session — all matching transcript evidence belongs to this goal."
            : otherGoals.map { "- \($0.goal) (activities: \($0.activities))" }.joined(separator: "\n")

        return Instructions("""
            \(assistantPreamble)

            This is the GOAL-DETAIL pass for ONE specific goal. A previous pass \
            already identified every goal addressed this session and the \
            activities performed toward each. Your job is to write the \
            observations and next steps for ONLY this goal — do not describe \
            evidence belonging to any other goal, even if it appears nearby in \
            the transcript.

            THIS GOAL:
            Goal: \(targetGoal.goal)
            Activities for this goal: \(targetGoal.activities)

            OTHER GOALS THIS SESSION (their evidence belongs to THEM — do not \
            reuse it here):
            \(otherGoalsList)

            \(coreEvidenceRules)

            WRITING STYLE:
            \(tone.promptText)
            """)
    }
}

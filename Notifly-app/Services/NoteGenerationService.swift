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

    static func generateSOAP(transcript: String, tone: NoteTone = .standard) async throws -> SOAPNote {
        try await generate(
            SOAPNote.self,
            transcript: transcript,
            tone: tone,
            formatGuidance: Self.soapGuidance,
            request: "Convert the transcript into a SOAP note."
        )
    }

    static func generateDAP(transcript: String, tone: NoteTone = .standard) async throws -> DAPNote {
        try await generate(
            DAPNote.self,
            transcript: transcript,
            tone: tone,
            formatGuidance: Self.dapGuidance,
            request: "Convert the transcript into a DAP note."
        )
    }

    static func generateGoalFocused(transcript: String, tone: NoteTone = .standard) async throws -> GoalFocusedNote {
        try await generate(
            GoalFocusedNote.self,
            transcript: transcript,
            tone: tone,
            formatGuidance: Self.goalFocusedGuidance,
            request: "Convert the transcript into a goal-focused clinical note."
        )
    }

    // MARK: - Core generation

    private static func generate<Output: Generable>(
        _ type: Output.Type,
        transcript: String,
        tone: NoteTone,
        formatGuidance: String,
        request: String
    ) async throws -> Output {
        try ensureModelAvailable()

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NoteGenerationError.emptyTranscript }

        let session = LanguageModelSession(instructions: instructions(tone: tone, formatGuidance: formatGuidance))
        let prompt = """
            \(request)

            Transcript:
            \(trimmed)
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

    // MARK: - Instructions

    /// Instructions are fixed for the whole session and take priority over
    /// the prompt, so the safety/evidence rules, tone, and format contract
    /// all live here.
    private static func instructions(tone: NoteTone, formatGuidance: String) -> Instructions {
        Instructions("""
            You are a clinical documentation assistant for allied health \
            professionals (occupational therapy, physiotherapy, speech \
            pathology, and similar disciplines). You turn a raw, imperfect \
            speech-to-text transcript of a clinician's post-session dictation \
            into a structured draft note.

            EVIDENCE RULES — these override everything else:
            0. SUFFICIENCY CHECK FIRST. Before filling any field, decide whether the \
            transcript actually contains clinical content from a real therapy session. \
            If it is a test recording, small talk, meta-commentary about the app, \
            empty/near-empty, or otherwise not a real clinical session, set \
            hasSufficientContent = false, write a brief reason in \
            insufficientContentReason, and LEAVE EVERY OTHER FIELD EMPTY. \
            Do not invent goals, activities, observations, or plans to fill the \
            schema. Refusing to generate a note is the correct outcome here.
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

            WRITING STYLE:
            \(tone.promptText)

            FORMAT:
            \(formatGuidance)
            """)
    }

    // MARK: - Per-format guidance

    private static let soapGuidance = """
        Produce a SOAP note. Place content in the correct section and do not \
        repeat the same information across sections:
        - Subjective: only what the client or their caregiver reported — \
        feelings, pain, concerns, events outside the session. Never the \
        clinician's own observations.
        - Objective: observable, measurable findings — activities performed \
        and the client's measured performance (counts, durations, assistance \
        levels).
        - Assessment: the clinician's stated interpretation of progress, \
        barriers, and responses. Synthesize only what was said.
        - Plan: explicitly stated next steps — next-session focus, home \
        programs, referrals, frequency changes.
        """

    private static let dapGuidance = """
        Produce a DAP note. Place content in the correct section and do not \
        repeat the same information across sections:
        - Data: all factual information from the session — what the client \
        or caregiver reported, activities performed, and measured performance \
        (counts, durations, assistance levels).
        - Assessment: the clinician's stated interpretation of progress, \
        barriers, and responses. Synthesize only what was said.
        - Plan: explicitly stated next steps — next-session focus, home \
        programs, referrals, frequency changes.
        """

    private static let goalFocusedGuidance = """
        Produce a goal-focused note: a brief session-level observation plus \
        one entry per distinct goal addressed. For each goal, populate \
        activities, observations, and nextSteps strictly from the transcript. \
        Include a goal only if an activity was actually performed against it \
        during the session. Do not duplicate goals or pad the list. If the \
        transcript does not mention any goals, return an empty goals array \
        rather than inventing one.
        """
}

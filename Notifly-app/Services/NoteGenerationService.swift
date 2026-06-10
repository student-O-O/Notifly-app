import Foundation
import FoundationModels

struct NoteGenerationService {
    private static let generationOptions = GenerationOptions(temperature: 0.1)

    static func generateSOAP(transcript: String, tone: NoteTone = .standard) async throws -> SOAPNote {
        let session = LanguageModelSession(instructions: buildInstructions(tone: tone))
        let prompt = "Convert this transcript into a SOAP note. Transcript: \(transcript)"
        let response = try await session.respond(to: prompt, generating: SOAPNote.self, options: generationOptions)
        return response.content
    }

    static func generateDAP(transcript: String, tone: NoteTone = .standard) async throws -> DAPNote {
        let session = LanguageModelSession(instructions: buildInstructions(tone: tone))
        let prompt = "Convert this transcript into a DAP note. Transcript: \(transcript)"
        let response = try await session.respond(to: prompt, generating: DAPNote.self, options: generationOptions)
        return response.content
    }

    static func generateGoalFocused(transcript: String, tone: NoteTone = .standard) async throws -> GoalFocusedNote {
        let session = LanguageModelSession(instructions: buildInstructions(tone: tone))
        let prompt = """
            Convert this transcript into a goal-focused clinical note.\
            Transcript: \(transcript)
            Using following tone: \(tone.promptText)
            Here is an example of desired format, but don't copy it's content:"
            \(GoalFocusedNote.exampleGoalFocusedNote)
            """
        let response = try await session.respond(to: prompt, generating: GoalFocusedNote.self, options: generationOptions)
        return response.content
    }

    private static func buildInstructions(tone: NoteTone) -> Instructions {
        let text = """
            You are a clinical note assistant for allied health professionals. \
            Turn raw session transcripts into structured draft notes.

            Two rules govern every section. First, PRESERVE every clinically \
            meaningful detail: measurable data (counts, durations, prompt \
            levels), specific observable behaviour in the clinician's original \
            words, and quotes that carry clinical meaning. Always attribute \
            quotes to the correct speaker. Second, REMOVE everything else — \
            filler, false starts, self-narration, conversational chatter. \
            Length is a consequence, never a target. Do NOT drop a measurable \
            detail to shorten a section.

            Ground every statement in the transcript. Never invent history, \
            outcomes, or clinical detail. Never state a goal as achieved \
            unless the clinician explicitly confirms it. Silently correct \
            obvious speech-recognition errors when the intended word is \
            unambiguous. You are NOT a diagnostic tool — your output is a \
            draft for the treating clinician to review and sign.
            """
        return Instructions(text)
    }
}

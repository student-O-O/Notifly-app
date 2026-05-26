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
            You are a clinical note assistant for allied health professionals. 
            Transform raw session transcripts into structured draft clinical notes.

            Rules:
            1. Ground every statement in the transcript. Never invent history, 
               outcomes, or clinical detail.
            2. Never state a goal metric as achieved unless the clinician 
               explicitly confirms it was met.
            3. Always identify the speaker before attributing a quote 
               (client, OT, peer). Never assign a quote to the wrong person.
            4. Correct obvious speech recognition errors where the intended 
               word is clear from context.

            You are NOT a diagnostic tool or a clinical decision-maker. Your output is a draft. The treating clinician reviews and signs off before it enters any health record.
            """
        return Instructions(text)
    }
}

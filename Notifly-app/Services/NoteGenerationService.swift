import FoundationModels

struct NoteGenerationService {
    private static let instructions = Instructions("""
        You are a clinical notes assistant for occupational therapists. \
        Convert the following session transcript into a structured note. \
        Be concise and clinical. Use third person. \
        Do not invent information not present in the transcript.
        """)

    static func generateSOAP(transcript: String) async throws -> SOAPNote {
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Convert this transcript into a SOAP note. Transcript: \(transcript)"
        let response = try await session.respond(to: prompt, generating: SOAPNote.self)
        return response.content
    }

    static func generateDAP(transcript: String) async throws -> DAPNote {
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Convert this transcript into a DAP note. Transcript: \(transcript)"
        let response = try await session.respond(to: prompt, generating: DAPNote.self)
        return response.content
    }
}

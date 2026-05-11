import Foundation
import FoundationModels

struct NoteGenerationService {
    private static let instructions = Instructions("""
        You are a clinical notes assistant for occupational therapists. \
        Convert the following session transcript into a structured note. \
        Be concise and clinical. Use third person. \
        Do not invent information not present in the transcript. \
        If there isn't enough information, say that not enough information was captured.
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

    static func generateCustom(transcript: String, sectionTitles: [String], promptInstructions: String?) async throws -> [CustomSection] {
        let session = LanguageModelSession(instructions: buildInstructions(promptInstructions))
        let sectionList = sectionTitles.joined(separator: ", ")
        let prompt = "Convert this transcript into a clinical note with exactly these sections: \(sectionList). Create one section for each title listed. Transcript: \(transcript)"

        let response = try await session.respond(to: prompt, generating: CustomGeneratedNote.self)

        var resultMap: [String: String] = [:]
        for section in response.content.sections {
            resultMap[section.title.lowercased()] = section.content
        }

        return sectionTitles.map { title in
            let content = resultMap[title.lowercased()]
                ?? resultMap.first(where: { $0.key.contains(title.lowercased()) || title.lowercased().contains($0.key) })?.value
                ?? ""
            return CustomSection(title: title, content: content)
        }
    }

    static func generateGoalEntries(transcript: String, fieldNames: [String], promptInstructions: String?) async throws -> CustomTableData {
        let session = LanguageModelSession(instructions: buildInstructions(promptInstructions))
        let fieldList = fieldNames.joined(separator: ", ")
        let prompt = """
            Extract each distinct goal or topic from this therapy session transcript. \
            For each goal, provide values for these fields: \(fieldList). \
            Each field value must be real content from the transcript, not the field name. \
            Only create entries for goals that are genuinely different. \
            If only one goal was discussed, return exactly one entry — do not duplicate or pad. \
            Transcript: \(transcript)
            """

        let response = try await session.respond(to: prompt, generating: GeneratedGoalEntries.self)

        var seen = Set<String>()
        var rows: [[String]] = []
        for entry in response.content.entries {
            let mapped = fieldNames.map { fieldName in
                let normalizedField = normalize(fieldName)
                return entry.fields.first(where: { normalize($0.fieldName) == normalizedField })?.content
                    ?? entry.fields.first(where: {
                        normalize($0.fieldName).contains(normalizedField)
                        || normalizedField.contains(normalize($0.fieldName))
                    })?.content
                    ?? ""
            }
            let key = mapped.first?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !key.isEmpty, seen.contains(key) { continue }
            if !key.isEmpty { seen.insert(key) }
            rows.append(mapped)
        }

        return CustomTableData(columns: fieldNames, rows: rows)
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isWhitespace }
            .trimmingCharacters(in: .whitespaces)
    }

    private static func buildInstructions(_ custom: String?) -> Instructions {
        if let custom, !custom.isEmpty {
            return Instructions("""
                You are a clinical notes assistant for occupational therapists. \
                Convert the following session transcript into a structured note. \
                Be concise and clinical. Use third person. \
                Do not invent information not present in the transcript. \
                If there isn't enough information, say that not enough information was captured. \
                Additional instructions: \(custom)
                """)
        }
        return instructions
    }
}

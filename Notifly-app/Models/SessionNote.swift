import Foundation
import SwiftData

@Model
final class SessionNote {
    var id: UUID
    var clientInitials: String
    var noteFormatRaw: String
    var date: Date
    var transcript: String?

    var subjective: String
    var objective: String
    var assessment: String
    var plan: String
    var data: String
    var goalsAddressed: String
    var timeSpent: String
    var interventionsUsed: String

    var noteFormat: NoteFormat {
        get { NoteFormat(rawValue: noteFormatRaw) ?? .soap }
        set { noteFormatRaw = newValue.rawValue }
    }

    init(
        clientInitials: String,
        noteFormat: NoteFormat,
        transcript: String?,
        subjective: String = "",
        objective: String = "",
        assessment: String = "",
        plan: String = "",
        data: String = "",
        goalsAddressed: String = "",
        timeSpent: String = "",
        interventionsUsed: String = ""
    ) {
        self.id = UUID()
        self.clientInitials = clientInitials
        self.noteFormatRaw = noteFormat.rawValue
        self.date = Date()
        self.transcript = transcript
        self.subjective = subjective
        self.objective = objective
        self.assessment = assessment
        self.plan = plan
        self.data = data
        self.goalsAddressed = goalsAddressed
        self.timeSpent = timeSpent
        self.interventionsUsed = interventionsUsed
    }

    var sections: [(title: String, keyPath: ReferenceWritableKeyPath<SessionNote, String>)] {
        switch noteFormat {
        case .soap:
            return [
                ("Subjective", \.subjective),
                ("Objective", \.objective),
                ("Assessment", \.assessment),
                ("Plan", \.plan),
                ("Goals Addressed", \.goalsAddressed),
                ("Time Spent", \.timeSpent),
                ("Interventions Used", \.interventionsUsed)
            ]
        case .dap:
            return [
                ("Data", \.data),
                ("Assessment", \.assessment),
                ("Plan", \.plan),
                ("Goals Addressed", \.goalsAddressed),
                ("Time Spent", \.timeSpent),
                ("Interventions Used", \.interventionsUsed)
            ]
        }
    }

    func asPlainText() -> String {
        var text = "\(noteFormat.rawValue) Note\n"
        text += "Client: \(clientInitials)\n"
        text += "Date: \(date.formatted(date: .long, time: .shortened))\n"
        text += String(repeating: "-", count: 40) + "\n\n"

        for section in sections {
            let value = self[keyPath: section.keyPath]
            if !value.isEmpty {
                text += "\(section.title):\n\(value)\n\n"
            }
        }

        return text
    }
}

import Foundation
import SwiftData

struct GoalCard: Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    var goal: String
    var activities: String
    var observations: String
    var nextSteps: String

    static func fromJSON(_ json: String) -> [GoalCard] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([GoalCard].self, from: data)) ?? []
    }

    static func toJSON(_ goals: [GoalCard]) -> String? {
        guard let data = try? JSONEncoder().encode(goals) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

@Model
final class SessionNote {
    var id: UUID
    var sessionID: UUID
    var clientInitials: String
    var noteFormatRaw: String
    var toneRaw: String
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

    var sessionObservations: String = ""
    var goalsJSON: String?

    var goalCards: [GoalCard] {
        get {
            guard let json = goalsJSON else { return [] }
            return GoalCard.fromJSON(json)
        }
        set {
            goalsJSON = GoalCard.toJSON(newValue)
        }
    }

    var noteFormat: NoteFormat {
        get { NoteFormat(rawValue: noteFormatRaw) ?? .soap }
        set { noteFormatRaw = newValue.rawValue }
    }

    var tone: NoteTone {
        get { NoteTone(rawValue: toneRaw) ?? .standard }
        set { toneRaw = newValue.rawValue }
    }

    init(
        clientInitials: String,
        noteFormat: NoteFormat,
        tone: NoteTone = .standard,
        sessionID: UUID = UUID(),
        transcript: String?,
        subjective: String = "",
        objective: String = "",
        assessment: String = "",
        plan: String = "",
        data: String = "",
        goalsAddressed: String = "",
        timeSpent: String = "",
        interventionsUsed: String = "",
        sessionObservations: String = "",
        goalCards: [GoalCard] = []
    ) {
        self.id = UUID()
        self.sessionID = sessionID
        self.clientInitials = clientInitials
        self.noteFormatRaw = noteFormat.rawValue
        self.toneRaw = tone.rawValue
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
        self.sessionObservations = sessionObservations
        if !goalCards.isEmpty {
            self.goalsJSON = GoalCard.toJSON(goalCards)
        }
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
        case .goalFocused:
            return []
        }
    }

    var displayName: String {
        noteFormat.rawValue
    }

    var toneLabel: String {
        tone == .standard ? "" : tone.rawValue
    }

    func asPlainText() -> String {
        var text = "\(displayName) Note\n"
        text += "Client: \(clientInitials)\n"
        text += "Date: \(date.formatted(date: .long, time: .shortened))\n"
        text += String(repeating: "-", count: 40) + "\n\n"

        if noteFormat == .goalFocused {
            if !sessionObservations.isEmpty {
                text += "Session Observations:\n\(sessionObservations)\n\n"
            }

            let cards = goalCards
            let useNumbering = cards.count > 1
            for (i, goal) in cards.enumerated() {
                let header = useNumbering ? "Goal \(i + 1): \(goal.goal)" : "Goal: \(goal.goal)"
                text += "\(header)\n"
                if !goal.activities.isEmpty {
                    text += "  Activities: \(goal.activities)\n"
                }
                if !goal.observations.isEmpty {
                    text += "  Observations: \(goal.observations)\n"
                }
                if !goal.nextSteps.isEmpty {
                    text += "  Next Steps: \(goal.nextSteps)\n"
                }
                text += "\n"
            }
        } else {
            for section in sections {
                let value = self[keyPath: section.keyPath]
                if !value.isEmpty {
                    text += "\(section.title):\n\(value)\n\n"
                }
            }
        }

        return text
    }
}

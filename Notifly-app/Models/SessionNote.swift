import Foundation
import SwiftData

struct CustomSection: Codable, Sendable {
    var title: String
    var content: String

    static func fromJSON(_ json: String) -> [CustomSection] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([CustomSection].self, from: data)) ?? []
    }

    static func toJSON(_ sections: [CustomSection]) -> String? {
        guard let data = try? JSONEncoder().encode(sections) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct CustomTableData: Codable, Sendable {
    var columns: [String]
    var rows: [[String]]

    static func fromJSON(_ json: String) -> CustomTableData? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CustomTableData.self, from: data)
    }

    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

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

    var templateName: String?
    var customSectionsJSON: String?
    var customTableJSON: String?
    var isTableFormat: Bool

    var noteFormat: NoteFormat {
        get { NoteFormat(rawValue: noteFormatRaw) ?? .soap }
        set { noteFormatRaw = newValue.rawValue }
    }

    var customSections: [CustomSection] {
        get {
            guard let json = customSectionsJSON else { return [] }
            return CustomSection.fromJSON(json)
        }
        set {
            customSectionsJSON = CustomSection.toJSON(newValue)
        }
    }

    var customTableData: CustomTableData? {
        get {
            guard let json = customTableJSON else { return nil }
            return CustomTableData.fromJSON(json)
        }
        set {
            customTableJSON = newValue?.toJSON()
        }
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
        interventionsUsed: String = "",
        templateName: String? = nil,
        customSections: [CustomSection] = [],
        customTableData: CustomTableData? = nil,
        isTableFormat: Bool = false
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
        self.templateName = templateName
        self.isTableFormat = isTableFormat
        if !customSections.isEmpty {
            self.customSectionsJSON = CustomSection.toJSON(customSections)
        }
        if let customTableData {
            self.customTableJSON = customTableData.toJSON()
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
        case .custom:
            return []
        }
    }

    var displayName: String {
        if noteFormat == .custom, let name = templateName {
            return name
        }
        return noteFormat.rawValue
    }

    func asPlainText() -> String {
        var text = "\(displayName) Note\n"
        text += "Client: \(clientInitials)\n"
        text += "Date: \(date.formatted(date: .long, time: .shortened))\n"
        text += String(repeating: "-", count: 40) + "\n\n"

        if noteFormat == .custom && isTableFormat, let table = customTableData {
            for (i, row) in table.rows.enumerated() {
                let header = table.columns.first ?? "Entry"
                text += "\(header) \(i + 1): \(row.first ?? "")\n"

                for colIndex in 1..<table.columns.count {
                    let value = colIndex < row.count ? row[colIndex] : ""
                    if !value.isEmpty {
                        text += "  \(table.columns[colIndex]): \(value)\n"
                    }
                }
                text += "\n"
            }
        } else if noteFormat == .custom {
            for section in customSections {
                if !section.content.isEmpty {
                    text += "\(section.title):\n\(section.content)\n\n"
                }
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

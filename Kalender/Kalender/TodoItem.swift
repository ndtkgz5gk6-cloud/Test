import Foundation
import SwiftData

enum Priority: Int, CaseIterable, Identifiable {
    case low = 0
    case normal = 1
    case high = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: return "Låg"
        case .normal: return "Normal"
        case .high: return "Hög"
        }
    }
}

@Model
final class TodoItem {
    /// Stabilt id, används bl.a. för påminnelser.
    var uuid: UUID
    var title: String
    var notes: String
    /// Datum (och ev. klockslag) för uppgiften. Utan klockslag sparas dagens början.
    var dueDate: Date
    var hasTime: Bool
    var hasReminder: Bool
    var isDone: Bool
    var priorityRaw: Int
    var createdAt: Date

    init(
        title: String,
        notes: String = "",
        dueDate: Date,
        hasTime: Bool = false,
        hasReminder: Bool = false,
        isDone: Bool = false,
        priority: Priority = .normal
    ) {
        self.uuid = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.hasReminder = hasReminder
        self.isDone = isDone
        self.priorityRaw = priority.rawValue
        self.createdAt = .now
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }
}

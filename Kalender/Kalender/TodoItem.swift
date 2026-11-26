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

enum Recurrence: Int, CaseIterable, Identifiable {
    case none = 0
    case daily = 1
    case weekdays = 2
    case weekly = 3
    case biweekly = 4
    case monthly = 5
    case yearly = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "Aldrig"
        case .daily: return "Varje dag"
        case .weekdays: return "Vardagar (mån–fre)"
        case .weekly: return "Varje vecka"
        case .biweekly: return "Varannan vecka"
        case .monthly: return "Varje månad"
        case .yearly: return "Varje år"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: return ""
        case .daily: return "Dagligen"
        case .weekdays: return "Vardagar"
        case .weekly: return "Varje vecka"
        case .biweekly: return "Varannan vecka"
        case .monthly: return "Varje månad"
        case .yearly: return "Varje år"
        }
    }
}

@Model
final class TodoItem {
    /// Stabilt id, används bl.a. för påminnelser.
    var uuid: UUID
    var title: String
    var notes: String
    /// Datum (och ev. klockslag) för uppgiften. För återkommande uppgifter: första tillfället.
    var dueDate: Date
    var hasTime: Bool
    var hasReminder: Bool
    /// Klar-status för uppgifter som inte upprepas.
    var isDone: Bool
    var priorityRaw: Int
    var createdAt: Date

    // Återkommande uppgifter (standardvärden gör att befintlig data migreras automatiskt)
    var recurrenceRaw: Int = 0
    /// Sista dagen serien kan inträffa (inklusive). `nil` = upprepas för alltid.
    var recurrenceEnd: Date? = nil
    /// Dagar då ett tillfälle av serien är avbockat.
    var completedDates: [Date] = []
    /// Dagar då ett enskilt tillfälle har raderats.
    var skippedDates: [Date] = []

    init(
        title: String,
        notes: String = "",
        dueDate: Date,
        hasTime: Bool = false,
        hasReminder: Bool = false,
        isDone: Bool = false,
        priority: Priority = .normal,
        recurrence: Recurrence = .none,
        recurrenceEnd: Date? = nil
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
        self.recurrenceRaw = recurrence.rawValue
        self.recurrenceEnd = recurrenceEnd
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }
}

// MARK: - Tillfällen

extension TodoItem {
    var isRecurring: Bool { recurrence != .none }

    /// Om uppgiften inträffar den här dagen.
    func occurs(on day: Date) -> Bool {
        let calendar = Calendar.app
        let target = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: dueDate)

        guard target >= start else { return false }
        if !isRecurring { return target == start }

        if let end = recurrenceEnd, target > calendar.startOfDay(for: end) { return false }
        if skippedDates.contains(where: { calendar.isDate($0, inSameDayAs: target) }) { return false }

        switch recurrence {
        case .none:
            return false
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: target)
            return weekday != 1 && weekday != 7 // 1 = söndag, 7 = lördag
        case .weekly, .biweekly:
            let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
            return days % (recurrence == .weekly ? 7 : 14) == 0
        case .monthly:
            return calendar.component(.day, from: target) == monthlyDay(in: target, calendar: calendar)
        case .yearly:
            guard calendar.component(.month, from: target) == calendar.component(.month, from: start) else {
                return false
            }
            return calendar.component(.day, from: target) == monthlyDay(in: target, calendar: calendar)
        }
    }

    /// Startdagens dagnummer, men som mest sista dagen i månaden (31:a → 30:e, 29 feb → 28 feb).
    private func monthlyDay(in month: Date, calendar: Calendar) -> Int {
        let startDay = calendar.component(.day, from: dueDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 31
        return min(startDay, daysInMonth)
    }

    func isDone(on day: Date) -> Bool {
        guard isRecurring else { return isDone }
        return completedDates.contains { Calendar.app.isDate($0, inSameDayAs: day) }
    }

    func toggleDone(on day: Date) {
        guard isRecurring else {
            isDone.toggle()
            return
        }
        let calendar = Calendar.app
        if isDone(on: day) {
            completedDates.removeAll { calendar.isDate($0, inSameDayAs: day) }
        } else {
            completedDates.append(calendar.startOfDay(for: day))
        }
    }

    /// Datum och tid för tillfället den här dagen.
    func occurrenceDate(on day: Date) -> Date {
        let calendar = Calendar.app
        return hasTime ? calendar.combine(day: day, time: dueDate) : calendar.startOfDay(for: day)
    }

    /// Kommande tillfällen som inte är avbockade, med början från `from`.
    func upcomingOccurrences(limit: Int, from: Date = .now) -> [Date] {
        guard isRecurring else {
            return !isDone && dueDate > from ? [dueDate] : []
        }
        let calendar = Calendar.app
        let today = calendar.startOfDay(for: from)
        var result: [Date] = []
        for offset in 0..<730 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            if let end = recurrenceEnd, day > calendar.startOfDay(for: end) { break }
            guard occurs(on: day), !isDone(on: day) else { continue }
            let date = occurrenceDate(on: day)
            if date > from {
                result.append(date)
                if result.count >= limit { break }
            }
        }
        return result
    }

    enum DeleteScope {
        case thisDay, thisAndFuture, all
    }

    /// Tar bort tillfällen ur serien. Returnerar `true` om hela uppgiften ska raderas.
    func removeOccurrences(_ scope: DeleteScope, day: Date) -> Bool {
        guard isRecurring else { return true }
        let calendar = Calendar.app
        let target = calendar.startOfDay(for: day)

        switch scope {
        case .all:
            return true
        case .thisDay:
            skippedDates.append(target)
            completedDates.removeAll { calendar.isDate($0, inSameDayAs: target) }
            return false
        case .thisAndFuture:
            guard let newEnd = calendar.date(byAdding: .day, value: -1, to: target),
                  newEnd >= calendar.startOfDay(for: dueDate) else { return true }
            recurrenceEnd = newEnd
            return false
        }
    }
}

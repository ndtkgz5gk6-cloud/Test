import Foundation

extension Calendar {
    /// Svensk kalender: veckan börjar på måndag och veckonummer enligt ISO 8601.
    static var app: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    /// Veckorna i månaden. Dagar utanför månaden är `nil`.
    func weeksInMonth(_ month: Date) -> [[Date?]] {
        let first = startOfMonth(for: month)
        guard let dayRange = range(of: .day, in: .month, for: first) else { return [] }

        let weekday = component(.weekday, from: first)
        let leading = (weekday - firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            cells.append(date(byAdding: .day, value: day - 1, to: first))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// Kombinerar datumdelen från `day` med klockslaget från `time`.
    func combine(day: Date, time: Date) -> Date {
        let d = dateComponents([.year, .month, .day], from: day)
        let t = dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year
        c.month = d.month
        c.day = d.day
        c.hour = t.hour
        c.minute = t.minute
        return date(from: c) ?? day
    }
}

extension Date {
    func svString(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.calendar = .app
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter.string(from: self)
    }

    var timeString: String { svString("HH:mm") }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

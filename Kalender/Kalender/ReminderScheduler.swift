import Foundation
import UserNotifications

enum ReminderScheduler {
    /// iOS tillåter max 64 väntande notiser per app, så vi schemalägger bara de närmaste
    /// tillfällena för återkommande uppgifter och fyller på när appen öppnas.
    static let maxPerItem = 8

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schemalägger om påminnelserna så att de matchar uppgiftens nuvarande läge.
    static func update(for item: TodoItem) {
        cancel(for: item)
        schedule(item)
    }

    /// Bygger om alla påminnelser. Anropas när appen blir aktiv.
    static func refreshAll(_ items: [TodoItem]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in items {
            schedule(item)
        }
    }

    static func cancel(for item: TodoItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers(for: item))
    }

    private static func identifiers(for item: TodoItem) -> [String] {
        [item.uuid.uuidString] + (0..<maxPerItem).map { "\(item.uuid.uuidString)#\($0)" }
    }

    private static func schedule(_ item: TodoItem) {
        guard item.hasReminder, item.hasTime else { return }

        for (index, date) in item.upcomingOccurrences(limit: maxPerItem).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.notes.isEmpty ? "Dags för din uppgift" : item.notes
            content.sound = .default

            let components = Calendar.app.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(item.uuid.uuidString)#\(index)", content: content, trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}

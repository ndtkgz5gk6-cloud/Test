import Foundation
import UserNotifications

enum ReminderScheduler {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schemalägger (eller tar bort) påminnelsen så att den matchar uppgiftens nuvarande läge.
    static func update(for item: TodoItem) {
        cancel(for: item)
        guard item.hasReminder, item.hasTime, !item.isDone, item.dueDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.notes.isEmpty ? "Dags för din uppgift" : item.notes
        content.sound = .default

        let components = Calendar.app.dateComponents(
            [.year, .month, .day, .hour, .minute], from: item.dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: item.uuid.uuidString, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for item: TodoItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [item.uuid.uuidString])
    }
}

import Foundation
import UserNotifications

enum ReminderSchedulerError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Autorisez les notifications d’Ecrin dans Réglages pour recevoir ce rappel."
        }
    }
}

@MainActor
struct ReminderScheduler {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(_ item: MemoryItem) async throws {
        let identifier = item.reminderID.uuidString
        guard let date = item.reminderAt, date > .now else {
            cancel(item)
            return
        }

        let settings = await center.notificationSettings()
        let isAuthorized: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        case .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
        guard isAuthorized else {
            throw ReminderSchedulerError.permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.summary.isEmpty ? item.content : item.summary
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancel(_ item: MemoryItem) {
        let identifier = item.reminderID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

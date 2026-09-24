import Foundation
import UserNotifications

/// The one notification Foundry sends: the Island session is over.
enum NotificationService {
    static let islandID = "foundry.island.end"

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.focus.error("Notification permission failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func scheduleIslandEnd(at date: Date, targetName: String?) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Island held."
        content.body = targetName.map { "Session complete. Back to \($0)." } ?? "Session complete. Come back to the Foundry."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: islandID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.focus.error("Schedule failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func cancelIslandEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [islandID])
    }
}

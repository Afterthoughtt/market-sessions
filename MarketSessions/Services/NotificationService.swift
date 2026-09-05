import Foundation
import UserNotifications

enum NotificationAuthorizationState: Hashable, Sendable {
    case notDetermined
    case authorized
    case denied
}

@MainActor
protocol NotificationCentering {
    /// Install the delegate so banners also show while the app is frontmost.
    func activate()
    func authorizationStatus() async -> NotificationAuthorizationState
    func requestAuthorization() async -> NotificationAuthorizationState
    func add(_ notifications: [PlannedNotification]) async
    func removePending(identifiers: [String])
    func removeAllPending()
}

@MainActor
final class NotificationCenterService: NotificationCentering {
    private let delegate = BannerDelegate()

    func activate() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        Self.map(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async -> NotificationAuthorizationState {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return await authorizationStatus()
    }

    func add(_ notifications: [PlannedNotification]) async {
        let center = UNUserNotificationCenter.current()
        for notification in notifications {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            let components = Calendar.autoupdatingCurrent.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: notification.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
        }
    }

    func removePending(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    nonisolated static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorizationState {
        switch status {
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}

private final class BannerDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

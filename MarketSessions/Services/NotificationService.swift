import Foundation
import UserNotifications

enum NotificationAuthorizationState: Hashable, Sendable {
    case notDetermined
    case authorized
    case denied
    /// macOS refused to register the app (for example an unsigned build); carries the system's reason.
    case unavailable(String)
}

@MainActor
protocol NotificationCentering {
    /// Install the delegate so banners also show while the app is frontmost.
    func activate()
    func authorizationStatus() async -> NotificationAuthorizationState
    func requestAuthorization() async -> NotificationAuthorizationState
    /// Returns only identifiers accepted by the system; all others remain eligible for retry.
    func add(_ notifications: [PlannedNotification]) async -> Set<String>
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
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return .unavailable(error.localizedDescription)
        }
        return await authorizationStatus()
    }

    func add(_ notifications: [PlannedNotification]) async -> Set<String> {
        let center = UNUserNotificationCenter.current()
        var accepted: Set<String> = []
        for notification in notifications {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            let trigger = Self.trigger(for: notification.fireDate)
            do {
                try await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
                accepted.insert(notification.id)
            } catch {
                // Omit failed requests so the next model refresh retries them.
                continue
            }
        }
        return accepted
    }

    nonisolated static func trigger(for date: Date) -> UNCalendarNotificationTrigger {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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

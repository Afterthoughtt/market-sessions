#if DEBUG
import SwiftUI

/// Xcode previews at fixed moments: by default Tue 2026-09-29 5:30 PM New York, so
/// New York is in After Hours. Stub services keep previews off the real login item,
/// notification center and preferences.
@MainActor
enum PreviewModel {
    static func make(
        day: Int = 29, hour: Int = 17, minute: Int = 30, displayZone: String = "America/New_York"
    ) -> MarketSessionsModel {
        let newYork = TimeZone(identifier: "America/New_York")!
        let display = TimeZone(identifier: displayZone)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
        return MarketSessionsModel(
            loginItemService: PreviewLoginItem(),
            notificationCenter: PreviewNotificationCenter(),
            nowProvider: { now },
            displayTimeZoneProvider: { display }
        )
    }
}

@MainActor
private final class PreviewLoginItem: LoginItemServicing {
    var state: LoginItemState = .disabled
    func setEnabled(_ enabled: Bool) throws { state = enabled ? .enabled : .disabled }
}

@MainActor
private final class PreviewNotificationCenter: NotificationCentering {
    func activate() {}
    func authorizationStatus() async -> NotificationAuthorizationState { .notDetermined }
    func requestAuthorization() async -> NotificationAuthorizationState { .notDetermined }
    func add(_ notifications: [PlannedNotification]) async -> Set<String> { Set(notifications.map(\.id)) }
    func removePending(identifiers: [String]) {}
    func removeAllPending() {}
}

#Preview("Popover") {
    SessionsPopover(model: PreviewModel.make())
}

#Preview("Popover – Asia Open") {
    // Wed 1:50 AM New York: Tokyo, Shanghai, Hong Kong and CME open; Tokyo closes in 40m.
    SessionsPopover(model: PreviewModel.make(day: 30, hour: 1, minute: 50))
}

#Preview("Popover – Owner Screenshot") {
    // Tue 11:21 PM Los Angeles (Wed 2:21 AM New York): Tokyo closes in 9m.
    SessionsPopover(model: PreviewModel.make(day: 30, hour: 2, minute: 21, displayZone: "America/Los_Angeles"))
}

#Preview("Settings – General") {
    SettingsView(model: PreviewModel.make(), tab: .general)
}

#Preview("Settings – Markets") {
    SettingsView(model: PreviewModel.make(), tab: .markets)
}

#Preview("Settings – Events") {
    SettingsView(model: PreviewModel.make(), tab: .events)
}

#Preview("Settings – Notifications") {
    SettingsView(model: PreviewModel.make(), tab: .notifications)
}

#Preview("Menu Bar Label") {
    let model = PreviewModel.make()
    VStack(alignment: .leading, spacing: 12) {
        ForEach(model.orderedSessions, id: \.session.id) { resolved in
            HStack(spacing: 4) {
                MenuBarLabel(resolved: resolved, now: model.now, displayTimeZone: model.displayTimeZone, showsCountdown: true)
            }
        }
    }
    .padding()
}
#endif

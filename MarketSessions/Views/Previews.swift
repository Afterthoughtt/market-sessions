#if DEBUG
import SwiftUI

/// Xcode previews at a fixed moment: Tue 2026-09-29 5:30 PM New York, so New York
/// is in After Hours. Stub services keep previews off the real login item,
/// notification center and preferences.
@MainActor
enum PreviewModel {
    static func make() -> MarketSessionsModel {
        let newYork = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 17, minute: 30))!
        return MarketSessionsModel(
            loginItemService: PreviewLoginItem(),
            notificationCenter: PreviewNotificationCenter(),
            nowProvider: { now },
            displayTimeZoneProvider: { newYork }
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

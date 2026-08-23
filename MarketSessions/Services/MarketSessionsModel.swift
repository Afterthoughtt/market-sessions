import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class MarketSessionsModel {
    private(set) var now = Date()
    private(set) var displayTimeZone = TimeZone.autoupdatingCurrent
    private(set) var sessions: [ResolvedSession] = []
    private(set) var focus: FocusSession?
    private(set) var loginItemState: LoginItemState = .disabled
    private(set) var loginItemError: String?

    private let catalog: [MarketSession]
    private let focusResolver: FocusSessionResolver
    private let loginItemService: any LoginItemServicing
    private let nowProvider: @Sendable () -> Date
    private let displayTimeZoneProvider: @Sendable () -> TimeZone
    private var clockTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []

    init(
        catalog: [MarketSession] = MarketScheduleCatalog.sessions,
        focusResolver: FocusSessionResolver = FocusSessionResolver(),
        loginItemService: any LoginItemServicing = LoginItemService(),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        displayTimeZoneProvider: @escaping @Sendable () -> TimeZone = { .autoupdatingCurrent }
    ) {
        self.catalog = catalog
        self.focusResolver = focusResolver
        self.loginItemService = loginItemService
        self.nowProvider = nowProvider
        self.displayTimeZoneProvider = displayTimeZoneProvider
        refresh()
    }

    func start() {
        guard clockTask == nil else {
            refresh()
            return
        }

        installNotificationObservers()
        refresh()
        clockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let current = Date().timeIntervalSince1970
                let remainder = current.truncatingRemainder(dividingBy: 60)
                let wait = max(0.05, 60 - remainder)
                do {
                    try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                } catch {
                    return
                }
                self?.refresh()
            }
        }
    }

    func refresh() {
        let snapshot = nowProvider()
        let timeZone = displayTimeZoneProvider()
        let resolver = SessionResolver(displayTimeZone: timeZone)
        now = snapshot
        displayTimeZone = timeZone
        sessions = resolver.resolve(catalog, at: snapshot)
        focus = focusResolver.resolve(sessions, at: snapshot)
        loginItemState = loginItemService.state
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            try loginItemService.setEnabled(enabled)
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItemState = loginItemService.state
    }

    func openLoginItemSettings() {
        loginItemService.openSystemSettings()
    }

    private func installNotificationObservers() {
        guard notificationObservers.isEmpty else { return }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            .NSSystemTimeZoneDidChange,
            .NSCalendarDayChanged,
        ]

        notificationObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
        }
    }
}

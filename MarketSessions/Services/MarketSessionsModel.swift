import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class MarketSessionsModel {
    private(set) var now = Date()
    private(set) var displayTimeZone = TimeZone.autoupdatingCurrent
    /// Frozen list order — re-sorted only when some session's state changes (a handover).
    private(set) var orderedSessions: [ResolvedSession] = []
    private(set) var focus = FocusSnapshot(openEntries: [], nextToOpen: nil)
    /// Fraction of the UTC day remaining — the header ring drains toward 00:00 UTC.
    private(set) var utcDayRemainingFraction: Double = 0
    private(set) var utcDayRemainingMinutes = 0
    private(set) var loginItemState: LoginItemState = .disabled
    private(set) var loginItemError: String?

    private let catalog: [MarketSession]
    private let focusResolver: FocusSessionResolver
    private let loginItemService: any LoginItemServicing
    private let nowProvider: @Sendable () -> Date
    private let displayTimeZoneProvider: @Sendable () -> TimeZone
    private var clockTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var sortedIDs: [MarketSession.ID] = []
    private var handoverSignature: [MarketSession.ID: SessionStatus] = [:]

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

        let resolved = resolver.resolve(catalog, at: snapshot)
        let signature = Dictionary(uniqueKeysWithValues: resolved.map { ($0.id, $0.status) })
        if signature != handoverSignature || sortedIDs.count != resolved.count {
            handoverSignature = signature
            sortedIDs = resolved
                .sorted { lhs, rhs in
                    let lhsDate = lhs.transition?.date ?? .distantFuture
                    let rhsDate = rhs.transition?.date ?? .distantFuture
                    if lhsDate == rhsDate {
                        return lhs.session.focusPriority < rhs.session.focusPriority
                    }
                    return lhsDate < rhsDate
                }
                .map(\.id)
        }
        let byID = Dictionary(uniqueKeysWithValues: resolved.map { ($0.id, $0) })
        orderedSessions = sortedIDs.compactMap { byID[$0] }

        focus = focusResolver.resolve(resolved, at: snapshot)
        updateUTCDay(at: snapshot)
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

    private func updateUTCDay(at date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            utcDayRemainingFraction = 0
            utcDayRemainingMinutes = 0
            return
        }
        let total = dayEnd.timeIntervalSince(dayStart)
        let remaining = max(0, dayEnd.timeIntervalSince(date))
        utcDayRemainingFraction = total > 0 ? min(max(remaining / total, 0), 1) : 0
        utcDayRemainingMinutes = FocusSessionResolver.remainingMinutes(until: dayEnd, from: date)
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

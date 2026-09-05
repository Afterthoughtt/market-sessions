import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class MarketSessionsModel {
    private(set) var now = Date()
    private(set) var displayTimeZone = TimeZone.autoupdatingCurrent
    private(set) var systemTimeZone = TimeZone.autoupdatingCurrent
    private(set) var preferences: MarketPreferences
    /// Frozen list order — re-sorted only when some session's state changes (a handover).
    private(set) var orderedSessions: [ResolvedSession] = []
    private(set) var focus = FocusSnapshot(openEntries: [], nextToOpen: nil)
    /// UTC-day metrics for the header readout, independent of the display zone.
    private(set) var utcDayRemainingFraction: Double = 0
    private(set) var utcDayRemainingMinutes = 0
    private(set) var upcomingEvents: UpcomingEconomicEvents = .empty
    private(set) var loginItemState: LoginItemState = .disabled
    private(set) var notificationAuthorization: NotificationAuthorizationState = .notDetermined
    /// In-flight write to the notification center; tests await it.
    private(set) var notificationSync: Task<Void, Never>?
    /// Last date the bundled holiday/early-close data covers; nil when absent.
    var exceptionCoverageEnd: Date? { marketExceptions.coverageEnd }
    /// The status item follows the session whose next transition happens first.
    var nextTransitionSession: ResolvedSession? { orderedSessions.first }
    var availableMarkets: [MarketSession] { catalog }

    private let catalog: [MarketSession]
    private let marketExceptions: MarketExceptionIndex
    private let economicEvents: [EconomicEvent]
    private let upcomingEventResolver = UpcomingEconomicEventResolver()
    private let focusResolver: FocusSessionResolver
    private let loginItemService: any LoginItemServicing
    private let notificationCenter: any NotificationCentering
    private let notificationPlanner = NotificationPlanner()
    private var scheduledNotifications: [PlannedNotification]?
    private var notificationAuthorizationRequest: Task<Void, Never>?
    private let nowProvider: @Sendable () -> Date
    private let displayTimeZoneProvider: @Sendable () -> TimeZone
    private let preferencesStore: UserDefaults?
    private var clockTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var sortedIDs: [MarketSession.ID] = []
    private var handoverSignature: [MarketSession.ID: SessionStatus] = [:]

    init(
        catalog: [MarketSession] = MarketScheduleCatalog.sessions,
        marketExceptions: MarketExceptionIndex? = nil,
        economicEvents: [EconomicEvent]? = nil,
        focusResolver: FocusSessionResolver = FocusSessionResolver(),
        loginItemService: any LoginItemServicing = LoginItemService(),
        notificationCenter: any NotificationCentering = NotificationCenterService(),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        displayTimeZoneProvider: @escaping @Sendable () -> TimeZone = { .autoupdatingCurrent },
        preferencesStore: UserDefaults? = nil
    ) {
        self.catalog = catalog
        self.marketExceptions = marketExceptions
            ?? ((try? MarketExceptionCatalog.loadIndex()) ?? .empty)
        self.economicEvents = economicEvents ?? ((try? EconomicEventCatalog.loadAll()) ?? [])
        self.focusResolver = focusResolver
        self.loginItemService = loginItemService
        self.notificationCenter = notificationCenter
        self.nowProvider = nowProvider
        self.displayTimeZoneProvider = displayTimeZoneProvider
        self.preferencesStore = preferencesStore
        self.preferences = preferencesStore.map(MarketPreferences.init(defaults:)) ?? MarketPreferences()
        refresh()
    }

    func start() {
        guard clockTask == nil else {
            refresh()
            refreshNotificationAuthorization()
            return
        }

        installNotificationObservers()
        notificationCenter.activate()
        refresh()
        refreshNotificationAuthorization()
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
        systemTimeZone = displayTimeZoneProvider()
        let timeZone = preferences.displayTimeZone(system: systemTimeZone)
        let resolver = SessionResolver(displayTimeZone: timeZone, exceptions: marketExceptions)
        now = snapshot
        displayTimeZone = timeZone

        let visibleCatalog = catalog.filter { preferences.visibleMarkets.contains($0.id) }
        let resolved = resolver.resolve(visibleCatalog, at: snapshot)
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
        upcomingEvents = upcomingEventResolver.resolve(
            economicEvents, at: snapshot, enabledKinds: preferences.eventKinds
        )
        updateUTCDay(at: snapshot)
        loginItemState = loginItemService.state
        syncNotifications(at: snapshot, resolver: resolver)
    }

    /// Replan and push only the difference to the notification center, so the
    /// per-minute refresh is free until a notification fires or a selection changes.
    private func syncNotifications(at now: Date, resolver: SessionResolver) {
        let planned = preferences.notifiesAnything
            ? notificationPlanner.plan(
                sessions: catalog.filter { preferences.notifiedMarkets.contains($0.id) },
                events: economicEvents.filter { preferences.notifiedEventKinds.contains($0.kind) },
                leadMinutes: preferences.notificationLeadMinutes,
                at: now,
                resolver: resolver,
                displayTimeZone: displayTimeZone
            )
            : []
        guard planned != scheduledNotifications else { return }

        let previous = scheduledNotifications
        scheduledNotifications = planned
        let removed = Set(previous ?? []).subtracting(planned).map(\.id)
        let added = planned.filter { !(previous ?? []).contains($0) }
        let center = notificationCenter
        let earlier = notificationSync
        notificationSync = Task { @MainActor in
            await earlier?.value
            if previous == nil {
                center.removeAllPending()
            } else if !removed.isEmpty {
                center.removePending(identifiers: removed)
            }
            await center.add(added)
        }
    }

    /// Re-read the system status; if the user already selected something but was
    /// never asked (or a previous ask failed), ask now.
    func refreshNotificationAuthorization() {
        let center = notificationCenter
        Task { @MainActor [weak self] in
            self?.notificationAuthorization = await center.authorizationStatus()
            self?.requestNotificationAuthorizationIfNeeded()
        }
    }

    func setNotifiedMarket(_ id: MarketSession.ID, enabled: Bool) {
        if enabled {
            preferences.notifiedMarkets.insert(id)
        } else {
            preferences.notifiedMarkets.remove(id)
        }
        requestNotificationAuthorizationIfNeeded()
        savePreferences()
    }

    func setNotifiedEventKind(_ kind: EconomicEventKind, enabled: Bool) {
        if enabled {
            preferences.notifiedEventKinds.insert(kind)
        } else {
            preferences.notifiedEventKinds.remove(kind)
        }
        requestNotificationAuthorizationIfNeeded()
        savePreferences()
    }

    func setNotificationLead(minutes: Int) {
        guard NotificationPlanner.leadOptions.contains(minutes) else { return }
        preferences.notificationLeadMinutes = minutes
        savePreferences()
    }

    /// One sample banner a second from now, so the user can confirm delivery and sound.
    func sendTestNotification() {
        let sample = PlannedNotification(
            id: "test", title: "Market Sessions",
            body: "Notifications are working. Market and event alerts will look like this.",
            fireDate: nowProvider().addingTimeInterval(1)
        )
        let center = notificationCenter
        Task { @MainActor [weak self] in
            if self?.notificationAuthorization != .authorized {
                self?.notificationAuthorization = await center.requestAuthorization()
            }
            await center.add([sample])
        }
    }

    private func requestNotificationAuthorizationIfNeeded() {
        guard preferences.notifiesAnything, notificationAuthorization == .notDetermined,
              notificationAuthorizationRequest == nil else { return }
        let center = notificationCenter
        notificationAuthorizationRequest = Task { @MainActor [weak self] in
            self?.notificationAuthorization = await center.requestAuthorization()
            self?.notificationAuthorizationRequest = nil
        }
    }

    /// Next bundled occurrence of a kind that has not yet ended, for Settings rows.
    func nextEvent(of kind: EconomicEventKind) -> EconomicEvent? {
        upcomingEventResolver
            .resolve(economicEvents, at: now, minimumCount: 1, enabledKinds: [kind])
            .events.first
    }

    /// Latest bundled end date in a category, for coverage readouts.
    func eventScheduleEnd(for category: EconomicEventKind.Category) -> Date? {
        economicEvents.filter { $0.kind.category == category }.map(\.end).max()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        try? loginItemService.setEnabled(enabled)
        loginItemState = loginItemService.state
    }

    func setMarket(_ id: MarketSession.ID, visible: Bool) {
        if visible {
            preferences.visibleMarkets.insert(id)
        } else {
            preferences.visibleMarkets.remove(id)
        }
        savePreferences()
    }

    func setEventKind(_ kind: EconomicEventKind, visible: Bool) {
        if visible {
            preferences.eventKinds.insert(kind)
        } else {
            preferences.eventKinds.remove(kind)
        }
        savePreferences()
    }

    func setDisplayTimeZone(_ identifier: String?) {
        guard identifier == nil || identifier.flatMap(TimeZone.init(identifier:)) != nil else { return }
        preferences.timeZoneIdentifier = identifier
        savePreferences()
    }

    private func savePreferences() {
        if let preferencesStore {
            preferences.save(to: preferencesStore)
        }
        refresh()
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

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
        self.nowProvider = nowProvider
        self.displayTimeZoneProvider = displayTimeZoneProvider
        self.preferencesStore = preferencesStore
        self.preferences = preferencesStore.map(MarketPreferences.init(defaults:)) ?? MarketPreferences()
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
    }

    /// Next bundled occurrence of a kind that has not yet ended, for Settings rows.
    func nextEvent(of kind: EconomicEventKind) -> EconomicEvent? {
        economicEvents
            .filter { $0.kind == kind && $0.end > now }
            .min { $0.start < $1.start }
    }

    /// Latest bundled end date among the given kinds, for coverage readouts.
    func eventScheduleEnd(for kinds: Set<EconomicEventKind>) -> Date? {
        economicEvents.filter { kinds.contains($0.kind) }.map(\.end).max()
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

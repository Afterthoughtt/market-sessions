import AppKit
import SwiftUI

struct SettingsView: View {
    let model: MarketSessionsModel
    @State private var selectedTab: SettingsTab

    init(model: MarketSessionsModel, tab: SettingsTab = .general) {
        self.model = model
        _selectedTab = State(initialValue: tab)
    }

    enum SettingsTab: Hashable {
        case general, markets, events, notifications
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("General", systemImage: "gearshape", value: .general) {
                general
            }
            Tab("Markets", systemImage: "globe.badge.clock", value: .markets) {
                markets
            }
            Tab("Events", systemImage: "calendar.badge.clock", value: .events) {
                events
            }
            Tab("Notifications", systemImage: "bell", value: .notifications) {
                notifications
            }
        }
        .frame(width: 520)
        .onAppear {
            model.start()
            model.setLiveSurface("settings", visible: true)
        }
        .onDisappear { model.setLiveSurface("settings", visible: false) }
    }

    private var general: some View {
        Form {
            Section {
                LabeledContent {
                    TimeZonePicker(model: model)
                        .help("Choose the time zone for market and event times")
                } label: {
                    SettingsRowLabel(
                        "Time Zone",
                        subtitle: TimeZonePicker.detail(for: model.displayTimeZone, at: model.now)
                    )
                }

                LabeledContent {
                    Text(coverageDetail)
                } label: {
                    SettingsRowLabel(
                        "Holiday Coverage",
                        subtitle: "Holidays and early closes for all six markets."
                    )
                }
            } footer: {
                Text("The time zone changes displayed times only. Daily Close stays at midnight UTC.")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { model.loginItemState.isEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )) {
                    SettingsRowLabel(
                        "Launch at Login",
                        subtitle: model.loginItemError.map {
                            "Couldn’t change Launch at Login (\($0)). Try again, or add Market Sessions in System Settings › Login Items."
                        }
                            ?? (model.loginItemState == .requiresApproval
                                ? "Approve Market Sessions in System Settings › Login Items."
                                : nil)
                    )
                }

                LabeledContent {
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    SettingsRowLabel("Quit Market Sessions")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var markets: some View {
        Form {
            Section {
                ForEach(model.availableMarkets) { market in
                    showAndNotifyRow(
                        SettingsRowLabel(market.name, subtitle: marketSubtitle(market)),
                        name: market.name,
                        show: Binding(
                            get: { model.preferences.visibleMarkets.contains(market.id) },
                            set: { model.setMarket(market.id, visible: $0) }
                        ),
                        notify: Binding(
                            get: { model.preferences.notifiedMarkets.contains(market.id) },
                            set: { model.setNotifiedMarket(market.id, enabled: $0) }
                        )
                    )
                }
            } footer: {
                Text("The switch shows a market in the popover and menu bar. Notify alerts at its first open and final close each trading day, even when it’s hidden. You can hide every market and still open Settings.\(notificationsOffNote)")
            }
        }
        .formStyle(.grouped)
    }

    private var events: some View {
        Form {
            eventSection("U.S. Releases", kinds: EconomicEventKind.kinds(in: .usRelease))
            eventSection("Central Banks", kinds: EconomicEventKind.kinds(in: .centralBank), footer: eventCoverageFooter)
        }
        .formStyle(.grouped)
    }

    private var notifications: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("Lead Time", selection: Binding(
                        get: { model.preferences.notificationLeadMinutes },
                        set: { model.setNotificationLead(minutes: $0) }
                    )) {
                        ForEach(NotificationPlanner.leadOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "At the time" : "\(minutes) minutes before").tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    SettingsRowLabel("Lead Time", subtitle: "Applies to every market and event notification.")
                }

                LabeledContent {
                    Group {
                        switch model.notificationAuthorization {
                        case .denied:
                            Button("Open System Settings…", action: openNotificationSettings)
                        case .unavailable:
                            Button("Try Again") { model.sendTestNotification() }
                        case .notDetermined, .authorized:
                            Button("Send Test Notification") { model.sendTestNotification() }
                        }
                    }
                } label: {
                    Group {
                        switch model.notificationAuthorization {
                        case .denied:
                            SettingsRowLabel(
                                "Notifications Are Off",
                                subtitle: "Allow Market Sessions in System Settings › Notifications."
                            )
                        case .unavailable(let reason):
                            SettingsRowLabel(
                                "Notifications Unavailable",
                                subtitle: "macOS didn’t allow the request (\(reason)). Click Try Again, or check System Settings › Notifications."
                            )
                        case .notDetermined, .authorized:
                            SettingsRowLabel("Test Notification", subtitle: "Shows a sample banner right away.")
                        }
                    }
                }
            } footer: {
                Text("Choose what notifies with the Notify checkboxes in Markets and Events. Markets notify at the first open and final close of each trading day; events at their scheduled time.")
            }
        }
        .formStyle(.grouped)
    }

    private func eventSection(_ title: String, kinds: [EconomicEventKind], footer: String? = nil) -> some View {
        Section {
            ForEach(kinds, id: \.self) { kind in
                showAndNotifyRow(
                    SettingsRowLabel(kind.compactTitle, subtitle: nextEventSubtitle(kind)),
                    name: kind.compactTitle,
                    show: Binding(
                        get: { model.preferences.eventKinds.contains(kind) },
                        set: { model.setEventKind(kind, visible: $0) }
                    ),
                    notify: Binding(
                        get: { model.preferences.notifiedEventKinds.contains(kind) },
                        set: { model.setNotifiedEventKind(kind, enabled: $0) }
                    )
                )
                .help(kind.detail)
            }
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }

    /// One market or event kind: a Notify checkbox, then the switch that shows it
    /// in the popover. Each control carries the row's name for VoiceOver.
    private func showAndNotifyRow(
        _ label: SettingsRowLabel,
        name: String,
        show: Binding<Bool>,
        notify: Binding<Bool>
    ) -> some View {
        LabeledContent {
            HStack(spacing: 16) {
                Toggle("Notify", isOn: notify)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel("Notify for \(name)")
                Toggle("Show \(name)", isOn: show)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        } label: {
            label
        }
    }

    /// Appended to the Markets and Events footers while macOS blocks notifications,
    /// since the Notify checkboxes would otherwise look like they work.
    private var notificationsOffNote: String {
        model.notificationAuthorization == .denied
            ? " Notifications are off in System Settings; see the Notifications tab."
            : ""
    }

    private func openNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func marketSubtitle(_ market: MarketSession) -> String? {
        market.id == .cmeFutures ? "Equity-index futures session" : nil
    }

    /// Kit row subtitle: the next bundled date in the display zone, or an honest gap.
    private func nextEventSubtitle(_ kind: EconomicEventKind) -> String {
        guard let next = model.nextEvent(of: kind) else {
            let coverageEnd = model.eventScheduleEnd(for: kind.category) ?? .distantPast
            return model.now > coverageEnd ? "Not in bundled schedule" : "No dates announced yet"
        }
        return MarketDateFormatting.dateTime(next.start, dateStyle: .medium, timeZone: model.displayTimeZone)
    }

    private var eventCoverageFooter: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: model.displayTimeZone)
        let us = model.eventScheduleEnd(for: .usRelease).map { $0.formatted(style) } ?? "unavailable"
        let banks = model.eventScheduleEnd(for: .centralBank).map { $0.formatted(style) } ?? "unavailable"
        return "The switch shows an event kind in the popover, which lists the next four. "
            + "Notify alerts at each event’s scheduled time. "
            + "Bundled dates run through \(us) for U.S. releases and \(banks) for central banks."
            + notificationsOffNote
    }

    private var coverageDetail: String {
        guard let end = model.exceptionCoverageEnd else { return "Unavailable" }
        let date = end.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: model.displayTimeZone))
        return model.now > end ? "Ended \(date)" : "Through \(date)"
    }
}

/// Form row label per Apple's macOS 26 kit (Examples › Form, "Leading
/// Accessories"): 13pt Medium title over an 11pt Medium secondary subtitle, 2pt apart.
private struct SettingsRowLabel: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

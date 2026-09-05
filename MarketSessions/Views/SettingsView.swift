import AppKit
import SwiftUI

struct SettingsView: View {
    let model: MarketSessionsModel
    @State private var selectedTab = SettingsTab.general

    private enum SettingsTab: Hashable {
        case general, markets, events

        /// Content height so the window fits each pane instead of a shared maximum.
        var height: CGFloat {
            switch self {
            case .general: 290
            case .markets: 350
            case .events: 660
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("General", systemImage: "gearshape", value: .general) {
                general
            }
            Tab("Markets", systemImage: "globe", value: .markets) {
                markets
            }
            Tab("Events", systemImage: "calendar", value: .events) {
                events
            }
        }
        .frame(width: 520, height: selectedTab.height)
        .onAppear { model.start() }
    }

    private var general: some View {
        Form {
            Section {
                LabeledContent {
                    TimeZonePicker(model: model)
                        .help("Time zone used for all market and event times")
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
                        subtitle: model.loginItemState == .requiresApproval
                            ? "Approve Market Sessions in System Settings › Login Items."
                            : nil
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
                    Toggle(isOn: Binding(
                        get: { model.preferences.visibleMarkets.contains(market.id) },
                        set: { model.setMarket(market.id, visible: $0) }
                    )) {
                        SettingsRowLabel(market.name, subtitle: marketSubtitle(market))
                    }
                }
            } footer: {
                Text("Applies to the popover and menu-bar indicator. You can hide every market and still open Settings.")
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

    private func eventSection(
        _ title: String,
        kinds: [EconomicEventKind],
        footer: String? = nil
    ) -> some View {
        Section {
            ForEach(kinds, id: \.self) { kind in
                Toggle(isOn: Binding(
                    get: { model.preferences.eventKinds.contains(kind) },
                    set: { model.setEventKind(kind, visible: $0) }
                )) {
                    SettingsRowLabel(kind.compactTitle, subtitle: nextEventSubtitle(kind))
                }
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

    private func marketSubtitle(_ market: MarketSession) -> String? {
        market.id == .cmeFutures ? "Equity-index futures session" : nil
    }

    /// Kit row subtitle: the next bundled date in the display zone, or an honest gap.
    private func nextEventSubtitle(_ kind: EconomicEventKind) -> String {
        guard let next = model.nextEvent(of: kind) else { return "No dates announced yet" }
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: model.displayTimeZone)
        let approximate = kind.hasApproximateTime ? " (approx.)" : ""
        return "\(next.start.formatted(style))\(approximate)"
    }

    private var eventCoverageFooter: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: model.displayTimeZone)
        let us = model.eventScheduleEnd(for: .usRelease).map { $0.formatted(style) } ?? "unavailable"
        let banks = model.eventScheduleEnd(for: .centralBank).map { $0.formatted(style) } ?? "unavailable"
        return "The popover shows only the next four upcoming events. "
            + "Bundled dates run through \(us) for U.S. releases and \(banks) for central banks."
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

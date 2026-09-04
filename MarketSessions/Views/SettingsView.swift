import AppKit
import SwiftUI

struct SettingsView: View {
    let model: MarketSessionsModel
    @State private var isChoosingTimeZone = false

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                general
            }
            Tab("Markets", systemImage: "globe") {
                markets
            }
            Tab("Events", systemImage: "calendar") {
                events
            }
        }
        .frame(width: 520, height: 500)
        .sheet(isPresented: $isChoosingTimeZone) {
            TimeZonePicker(model: model)
        }
        .onAppear { model.start() }
    }

    private var general: some View {
        Form {
            Section {
                LabeledContent("Time zone") {
                    Button(timeZoneLabel) { isChoosingTimeZone = true }
                        .help("Choose the time zone used for all market and event times")
                }
                Text("System time is detected automatically by default. A custom time zone changes displayed times, not market schedules. Daily Close stays at midnight UTC.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.loginItemState.isEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if model.loginItemState == .requiresApproval {
                    Text("Approve Market Sessions in System Settings → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Schedule data") {
                Text(coverageDescription)
                Text("Schedules are bundled and work offline. CME follows the equity-index futures session. BOJ announcement times are approximate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Quit Market Sessions") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .formStyle(.grouped)
    }

    private var markets: some View {
        Form {
            Section {
                ForEach(model.availableMarkets) { market in
                    Toggle(market.name, isOn: Binding(
                        get: { model.preferences.visibleMarkets.contains(market.id) },
                        set: { model.setMarket(market.id, visible: $0) }
                    ))
                }
            } header: {
                Text("Show markets")
            } footer: {
                Text("Applies to the popover and menu-bar indicator. You can hide every market and still access Settings.")
            }
        }
        .formStyle(.grouped)
    }

    private var events: some View {
        Form {
            eventSection("U.S. releases", kinds: [.employment, .cpi, .pce, .ppi, .retailSales, .gdp])
            eventSection("Central banks", kinds: [.fomc, .fomcMinutes, .fedSpeech, .ecb, .boj])
            Text("The next four selected events appear in the popover. Turn all off to hide the section.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private func eventSection(_ title: String, kinds: [EconomicEventKind]) -> some View {
        Section(title) {
            ForEach(kinds, id: \.self) { kind in
                Toggle(isOn: Binding(
                    get: { model.preferences.eventKinds.contains(kind) },
                    set: { model.setEventKind(kind, visible: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.compactTitle)
                        if kind.title != kind.compactTitle {
                            Text(kind.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .help(kind.title)
            }
        }
    }

    private var timeZoneLabel: String {
        if let identifier = model.preferences.timeZoneIdentifier {
            return identifier.replacingOccurrences(of: "_", with: " ")
        }
        let abbreviation = model.systemTimeZone.abbreviation(for: model.now)
            ?? model.systemTimeZone.identifier
        return "System — \(abbreviation)"
    }

    private var coverageDescription: String {
        guard let end = model.exceptionCoverageEnd else {
            return "Recurring hours only; holiday data is unavailable."
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = model.displayTimeZone
        let date = formatter.string(from: end)
        return model.now > end
            ? "Holiday data ended \(date). Using recurring hours."
            : "Includes holidays and early closes through \(date)."
    }
}

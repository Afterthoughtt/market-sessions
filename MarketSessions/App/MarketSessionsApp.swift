import SwiftUI

@main
@MainActor
struct MarketSessionsApp: App {
    /// Xcode's preview host launches the whole app. Keep that copy out of the menu bar
    /// and away from the real preferences, login item and notification queue.
    #if DEBUG
    private static let isPreviewHost = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    @State private var model = isPreviewHost ? PreviewModel.make() : MarketSessionsModel(preferencesStore: .standard)
    #else
    private static let isPreviewHost = false
    @State private var model = MarketSessionsModel(preferencesStore: .standard)
    #endif

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!Self.isPreviewHost)) {
            SessionsPopover(model: model)
        } label: {
            MenuBarLabel(
                resolved: model.nextTransitionSession,
                now: model.now,
                displayTimeZone: model.displayTimeZone,
                showsCountdown: model.preferences.showsMenuBarCountdown
            )
                .task {
                    model.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}

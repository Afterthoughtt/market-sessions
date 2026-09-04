import SwiftUI

@main
@MainActor
struct MarketSessionsApp: App {
    @State private var model = MarketSessionsModel(preferencesStore: .standard)

    var body: some Scene {
        MenuBarExtra {
            SessionsPopover(model: model)
        } label: {
            MenuBarLabel(
                resolved: model.nextTransitionSession,
                now: model.now,
                displayTimeZone: model.displayTimeZone
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

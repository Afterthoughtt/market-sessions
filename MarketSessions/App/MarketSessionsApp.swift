import SwiftUI

@main
@MainActor
struct MarketSessionsApp: App {
    @State private var model = MarketSessionsModel()

    var body: some Scene {
        MenuBarExtra {
            SessionsPopover(model: model)
        } label: {
            MenuBarLabel(focus: model.focus)
                .task {
                    model.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

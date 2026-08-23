import SwiftUI

struct MenuBarLabel: View {
    let focus: FocusSession?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.xyaxis.line")
            Text(focus?.countdownText ?? "--m")
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let focus else { return "Market Sessions, schedule unavailable" }
        return "Market Sessions, \(focus.sessionName), \(focus.actionLabel) \(focus.accessibilityCountdownText)"
    }
}

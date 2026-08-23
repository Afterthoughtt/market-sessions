import AppKit
import SwiftUI

struct SessionsPopover: View {
    let model: MarketSessionsModel
    @State private var expandedSessionID: MarketSession.ID?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Market Sessions")
                    .font(.title3.weight(.semibold))

                FocusSessionCard(
                    focus: model.focus,
                    now: model.now,
                    displayTimeZone: model.displayTimeZone
                )
            }
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.sessions) { resolved in
                        SessionRow(
                            resolved: resolved,
                            isExpanded: expandedSessionID == resolved.id,
                            now: model.now,
                            displayTimeZone: model.displayTimeZone
                        ) {
                            expandedSessionID = expandedSessionID == resolved.id ? nil : resolved.id
                        }

                        if resolved.id != model.sessions.last?.id {
                            Divider()
                                .padding(.leading, 28)
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "Recurring hours only — holidays and early closes are not adjusted.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { model.loginItemState.isEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )

                if let detail = model.loginItemState.detail {
                    HStack(alignment: .firstTextBaseline) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if model.loginItemState == .requiresApproval {
                            Spacer()
                            Button("Open Login Items") {
                                model.openLoginItemSettings()
                            }
                            .font(.caption)
                        }
                    }
                }

                if let error = model.loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .padding(14)
        }
        .frame(width: 390, height: 590)
        .task {
            model.start()
        }
        .onAppear {
            model.refresh()
        }
    }
}

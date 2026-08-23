import SwiftUI

struct SessionDetail: View {
    let resolved: ResolvedSession
    let now: Date
    let displayTimeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailLine(title: "Market zone", value: resolved.session.canonicalTimeZoneIdentifier)
            detailLine(title: "Local zone", value: displayTimeZone.identifier)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today’s local intervals")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if resolved.todayIntervals.isEmpty {
                    Text("No recurring hours today")
                        .font(.caption)
                } else {
                    ForEach(Array(resolved.todayIntervals.enumerated()), id: \.offset) { _, interval in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(interval.kind.displayName)
                                .foregroundStyle(interval.kind.countsAsActive ? .primary : .secondary)
                            Spacer(minLength: 8)
                            Text(
                                MarketDateFormatting.interval(
                                    start: interval.start,
                                    end: interval.end,
                                    timeZone: displayTimeZone
                                )
                            )
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }

            if let transition = resolved.transition {
                detailLine(
                    title: "Next transition",
                    value: "\(transition.kind.rawValue) \(MarketDateFormatting.transition(transition.date, relativeTo: now, timeZone: displayTimeZone))"
                )
            }

            if let caveat = resolved.session.caveat {
                Text(caveat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
        .padding(.leading, 28)
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.caption)
    }
}

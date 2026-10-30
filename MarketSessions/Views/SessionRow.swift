import SwiftUI

/// One market: its name over the next change (`Closes 11:30 PM`), and the time
/// until that change as the row's main value, `9m left` while trading and
/// `in 7h 9m` otherwise. The section header above carries the state's color.
struct SessionRow: View {
    let resolved: ResolvedSession
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(resolved.session.name)
                    .font(.body)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(detail)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(palette.sec)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let remaining {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if resolved.status.isActive {
                        Text(remaining)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.text)
                        Text("left")
                            .font(.subheadline)
                            .foregroundStyle(palette.sec)
                    } else {
                        Text("in")
                            .font(.subheadline)
                            .foregroundStyle(palette.sec)
                        Text(remaining)
                            .font(.body)
                            .foregroundStyle(isExtendedHours ? palette.text : palette.sec)
                    }
                }
                .monospacedDigit()
                .fixedSize()
            }
        }
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            if resolved.status.isActive {
                // The kit's Small determinate bar: 6pt, fully rounded, filling toward the
                // close, and never narrower than a dot of its own height.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.track)
                        let elapsed = resolved.elapsedFraction(at: now)
                        if elapsed > 0 {
                            Capsule()
                                .fill(palette.sec)
                                .frame(width: max(proxy.size.height, proxy.size.width * elapsed))
                        }
                    }
                }
                .frame(height: 6)
                .offset(y: 4)
                .accessibilityHidden(true)
            }
        }
        .padding(.bottom, resolved.status.isActive ? 10 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var isExtendedHours: Bool {
        resolved.status == .preMarket || resolved.status == .postMarket
    }

    /// Lunch recesses and CME's maintenance hour are Closed; their row says Reopens.
    private var verb: String {
        guard let transition = resolved.transition else { return "" }
        switch resolved.currentOccurrence?.kind {
        case .recess, .maintenance: return "Reopens"
        default: return transition.verb.rawValue
        }
    }

    private var detail: String {
        guard let transition = resolved.transition else { return "" }
        let time = MarketDateFormatting.transitionTime(transition.date, relativeTo: now, timeZone: displayTimeZone)
        return "\(verb) \(time)"
    }

    private var remainingMinutes: Int? {
        resolved.transition.map { FocusSessionResolver.remainingMinutes(until: $0.date, from: now) }
    }

    private var remaining: String? {
        remainingMinutes.map { MarketDurationFormatting.compact(minutes: $0) }
    }

    private var accessibilityText: String {
        var parts = [resolved.session.name, resolved.status.label, detail]
        if let minutes = remainingMinutes {
            let spoken = MarketDurationFormatting.spoken(minutes: minutes)
            parts.append(resolved.status.isActive ? "\(spoken) left" : "in \(spoken)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

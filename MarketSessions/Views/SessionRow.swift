import SwiftUI

/// A currently trading session: name, local close time, and time remaining.
struct OpenSessionRow: View {
    let resolved: ResolvedSession
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(resolved.session.name)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(transitionText)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(palette.sec)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.track)
                    if remainingFraction > 0 {
                        Capsule()
                            .fill(palette.ringSec)
                            .frame(width: proxy.size.width * remainingFraction)
                    }
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(resolved.session.name), \(resolved.status.label), \(transitionText)"
        )
    }

    private var remainingFraction: Double {
        resolved.remainingTradingFraction(at: now)
    }

    private var transitionText: String {
        guard let transition = resolved.transition else { return "" }
        let time = MarketDateFormatting.transitionTime(
            transition.date,
            relativeTo: now,
            timeZone: displayTimeZone
        )
        return "\(transition.verb.rawValue) \(time)"
    }
}

/// A non-trading session: name and the local time of its next state change.
/// Pre-market and after-hours rows carry a vertical system-color tint on the
/// kit's 24pt / 8pt-radius menu-item highlight geometry, extended 7pt past
/// the text inset like the Settings hover.
struct ClosedSessionRow: View {
    let resolved: ResolvedSession
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    var body: some View {
        HStack(spacing: 10) {
            Text(resolved.session.name)
                .font(.system(size: 13))
                .foregroundStyle(palette.text)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(transitionText)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(palette.sec)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(tintBackground)
        .padding(.horizontal, -7)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(resolved.session.name), \(resolved.status.label), \(transitionText)"
        )
    }

    @ViewBuilder
    private var tintBackground: some View {
        if let tint = palette.extendedHoursTint(resolved.status) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var transitionText: String {
        guard let transition = resolved.transition else { return "" }
        let time = MarketDateFormatting.transitionTime(
            transition.date,
            relativeTo: now,
            timeZone: displayTimeZone
        )
        return "\(transition.verb.rawValue) \(time)"
    }
}

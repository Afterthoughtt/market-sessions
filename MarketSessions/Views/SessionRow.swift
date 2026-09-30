import SwiftUI

/// A currently trading session: name, local close time, and time remaining.
struct OpenSessionRow: View {
    let resolved: ResolvedSession
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette
    /// The session the menu bar shows; only its countdown is emphasized.
    let isNext: Bool

    var body: some View {
        // A 24pt text line (the kit's menu item height) over the kit's Small (6pt)
        // determinate bar.
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(resolved.session.name)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)

                Spacer(minLength: 6)

                TransitionText(label: label, palette: palette, emphasized: isNext)
            }
            .frame(height: 24)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.track)
                    // The kit's fill never shrinks below a round dot of the bar's height.
                    if elapsedFraction > 0 {
                        Capsule()
                            .fill(palette.ringSec)
                            .frame(width: max(proxy.size.height, proxy.size.width * elapsedFraction))
                    }
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(resolved.session.name), \(resolved.status.label), \(label.spoken)"
        )
    }

    private var elapsedFraction: Double {
        resolved.elapsedTradingFraction(at: now)
    }

    private var label: TransitionLabel {
        TransitionLabel(resolved: resolved, now: now, displayTimeZone: displayTimeZone)
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
    /// The session the menu bar shows; only its countdown is emphasized.
    let isNext: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(resolved.session.name)
                .font(.system(size: 13))
                .foregroundStyle(palette.text)
                .lineLimit(1)

            Spacer(minLength: 6)

            TransitionText(label: label, palette: palette, emphasized: isNext)
        }
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(tintBackground)
        .padding(.horizontal, -7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(resolved.session.name), \(resolved.status.label), \(label.spoken)"
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

    private var label: TransitionLabel {
        TransitionLabel(resolved: resolved, now: now, displayTimeZone: displayTimeZone)
    }
}

/// A row's next change: `Closes 11:30 PM`, or inside the menu bar's countdown window
/// `Closes in 40m`.
private struct TransitionLabel {
    let text: String
    let spoken: String
    let isImminent: Bool

    init(resolved: ResolvedSession, now: Date, displayTimeZone: TimeZone) {
        guard let transition = resolved.transition else {
            (text, spoken, isImminent) = ("", "", false)
            return
        }
        let verb = transition.verb.rawValue
        if let countdown = MenuBarLabel.countdown(for: resolved, now: now) {
            let minutes = FocusSessionResolver.remainingMinutes(until: transition.date, from: now)
            text = "\(verb) in \(countdown)"
            spoken = "\(verb) in \(MarketDurationFormatting.spoken(minutes: minutes))"
            isImminent = true
        } else {
            let time = MarketDateFormatting.transitionTime(transition.date, relativeTo: now, timeZone: displayTimeZone)
            text = "\(verb) \(time)"
            spoken = text
            isImminent = false
        }
    }
}

/// Semibold primary only for the menu bar's own countdown, so one row stands out.
private struct TransitionText: View {
    let label: TransitionLabel
    let palette: MarketPalette
    let emphasized: Bool

    var body: some View {
        let emphasis = emphasized && label.isImminent
        Text(label.text)
            .font(.system(size: 13, weight: emphasis ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(emphasis ? palette.text : palette.sec)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

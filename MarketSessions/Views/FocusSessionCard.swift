import SwiftUI

/// Region A3 — the "Open now" grid: one emphasized cell, then up to two secondary
/// cells for other open sessions. Capped at three cells by decision; further open
/// sessions are counted in the section label and always visible in the list below.
/// On the weekend the single cell shows the next session to open.
struct OpenNowGrid: View {
    let focus: FocusSnapshot
    let now: Date
    let displayTimeZone: TimeZone
    let palette: MarketPalette

    var body: some View {
        VStack(spacing: 7) {
            if let hero = focus.hero {
                heroOpenCell(hero)
                let secondary = Array(focus.secondary.prefix(2))
                if secondary.count == 1 {
                    secondaryStrip(secondary[0])
                } else if secondary.count == 2 {
                    HStack(spacing: 7) {
                        secondaryCell(secondary[0])
                        secondaryCell(secondary[1])
                    }
                }
            } else if let next = focus.nextToOpen {
                heroNextCell(next)
            }
        }
    }

    private func heroOpenCell(_ entry: FocusSnapshot.OpenEntry) -> some View {
        let subtitle = MarketDateFormatting.subtitleTransition(
            entry.transition,
            relativeTo: now,
            timeZone: displayTimeZone
        )
        return heroCell(
            code: entry.code,
            ringFraction: entry.remainingFraction,
            name: entry.name,
            statusWord: entry.status.label,
            statusColor: palette.statusColor(entry.status),
            subtitleTail: subtitle,
            actionLabel: "\(entry.transition.verb.rawValue) in",
            remainingMinutes: entry.remainingMinutes
        )
    }

    private func heroNextCell(_ next: FocusSnapshot.NextEntry) -> some View {
        let transition = SessionTransition(verb: .opens, date: next.opensAt)
        let subtitle = MarketDateFormatting.subtitleTransition(
            transition,
            relativeTo: now,
            timeZone: displayTimeZone
        )
        return heroCell(
            code: next.code,
            ringFraction: next.fillFraction,
            name: next.name,
            statusWord: "Closed",
            statusColor: palette.sec,
            subtitleTail: subtitle,
            actionLabel: "Opens in",
            remainingMinutes: next.remainingMinutes
        )
    }

    private func heroCell(
        code: String,
        ringFraction: Double,
        name: String,
        statusWord: String,
        statusColor: Color,
        subtitleTail: String,
        actionLabel: String,
        remainingMinutes: Int
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                ProgressRing(
                    fraction: ringFraction,
                    size: 52,
                    lineWidth: 4,
                    track: palette.track,
                    arc: palette.accent
                )
                Text(code)
                    .font(.system(size: code.count >= 4 ? 12 : 13, weight: .semibold))
                    .tracking(-0.13)
                    .foregroundStyle(palette.text)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(
                    "\(Text(statusWord).fontWeight(.semibold).foregroundColor(statusColor)) \(Text("· \(subtitleTail)").foregroundColor(palette.sec))"
                )
                .font(.system(size: 11))
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(actionLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.sec)
                Text(MarketDurationFormatting.compact(minutes: remainingMinutes))
                    .font(.system(size: 19, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
            }
        }
        .padding(12)
        .background(palette.cell, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(palette.accentRing, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(name), \(statusWord.lowercased()), \(actionLabel.lowercased()) "
                + MarketDurationFormatting.spoken(minutes: remainingMinutes)
        )
    }

    /// A lone secondary session gets a slim full-width strip instead of a card:
    /// a stretched card leaves most of its width empty and competes with the hero.
    /// Both ends are anchored — name leading, countdown trailing — so it reads as a
    /// subordinate row, echoing the session list below.
    private func secondaryStrip(_ entry: FocusSnapshot.OpenEntry) -> some View {
        HStack(spacing: 9) {
            ProgressRing(
                fraction: entry.remainingFraction,
                size: 18,
                lineWidth: 2,
                track: palette.track,
                arc: palette.accent
            )

            Text(entry.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            Text("\(MarketDurationFormatting.compact(minutes: entry.remainingMinutes)) left")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(palette.sec)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(palette.cell, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(entry.name), open, "
                + MarketDurationFormatting.spoken(minutes: entry.remainingMinutes) + " left"
        )
    }

    private func secondaryCell(_ entry: FocusSnapshot.OpenEntry) -> some View {
        HStack(spacing: 9) {
            ProgressRing(
                fraction: entry.remainingFraction,
                size: 24,
                lineWidth: 2.5,
                track: palette.track,
                arc: palette.accent
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(MarketDurationFormatting.compact(minutes: entry.remainingMinutes)) left")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(palette.sec)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(palette.cell, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(entry.name), open, "
                + MarketDurationFormatting.spoken(minutes: entry.remainingMinutes) + " left"
        )
    }
}

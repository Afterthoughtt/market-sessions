import SwiftUI

/// Shared colors. Neutral text, separator, and track values follow Apple's
/// macOS 26 UI kit label and fill tokens (see CLAUDE.md, design reference);
/// legacy status colors remain available to non-popover views.
struct MarketPalette {
    let text: Color
    let sec: Color
    let faint: Color
    let divider: Color
    let dividerStrong: Color
    let cell: Color
    let track: Color
    let ringTrack: Color
    let ringSec: Color
    let accent: Color
    let accentRing: Color
    let green: Color
    let orange: Color
    let purple: Color
    let popover: Color

    static let light = MarketPalette(
        text: Color.black.opacity(0.85),
        sec: Color.black.opacity(0.5),
        faint: Color.black.opacity(0.5),
        divider: Color.black.opacity(0.07),
        dividerStrong: Color.black.opacity(0.08),
        cell: Color.white.opacity(0.72),
        track: Color.black.opacity(0.08),
        ringTrack: Color.black.opacity(0.12),
        ringSec: Color.black.opacity(0.5),
        accent: Color(red: 0, green: 122 / 255, blue: 1),
        accentRing: Color(red: 0, green: 122 / 255, blue: 1).opacity(0.28),
        green: Color(red: 0x1E / 255, green: 0x7A / 255, blue: 0x34 / 255),
        orange: Color(red: 0x8A / 255, green: 0x61 / 255, blue: 0x00 / 255),
        purple: Color(red: 0x89 / 255, green: 0x44 / 255, blue: 0xAB / 255),
        popover: Color(red: 246 / 255, green: 246 / 255, blue: 246 / 255).opacity(0.96)
    )

    static let dark = MarketPalette(
        text: Color.white.opacity(0.85),
        sec: Color.white.opacity(0.55),
        faint: Color.white.opacity(0.55),
        divider: Color.white.opacity(0.09),
        dividerStrong: Color.white.opacity(0.09),
        cell: Color.white.opacity(0.07),
        track: Color.white.opacity(0.08),
        ringTrack: Color.white.opacity(0.18),
        ringSec: Color.white.opacity(0.55),
        accent: Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255),
        accentRing: Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255).opacity(0.55),
        green: Color(red: 0x32 / 255, green: 0xD7 / 255, blue: 0x4B / 255),
        orange: Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255),
        purple: Color(red: 0xBF / 255, green: 0x5A / 255, blue: 0xF2 / 255),
        popover: Color(red: 30 / 255, green: 30 / 255, blue: 32 / 255).opacity(0.97)
    )

    static func palette(for scheme: ColorScheme) -> MarketPalette {
        scheme == .dark ? .dark : .light
    }

    func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .open: green
        case .onBreak: orange
        case .closed: sec
        }
    }
}

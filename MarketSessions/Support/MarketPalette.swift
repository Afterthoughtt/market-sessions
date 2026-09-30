import SwiftUI

/// Shared colors. Neutral text and separator values follow Apple's
/// macOS 26 UI kit label and fill tokens (see CLAUDE.md, design reference);
/// state colors are system colors (`stateColor`).
struct MarketPalette {
    let text: Color
    let sec: Color
    let openText: Color
    let preMarketText: Color
    let afterHoursText: Color
    let faint: Color
    let divider: Color
    let dividerStrong: Color
    let cell: Color
    let ringTrack: Color
    let accent: Color
    let accentRing: Color
    let popover: Color

    static let light = MarketPalette(
        text: Color.black.opacity(0.85),
        sec: Color.black.opacity(0.5),
        // Kit light Green #34C759, Orange #FF8D28 and Blue #0088FF measure 2.1, 2.1
        // and 3.3:1 on the light popover; each is darkened just to 4.5:1 for 11pt text.
        openText: Color(red: 0x22 / 255, green: 0x81 / 255, blue: 0x3A / 255),
        preMarketText: Color(red: 0xA8 / 255, green: 0x5D / 255, blue: 0x1A / 255),
        afterHoursText: Color(red: 0x00 / 255, green: 0x71 / 255, blue: 0xD4 / 255),
        faint: Color.black.opacity(0.5),
        divider: Color.black.opacity(0.07),
        dividerStrong: Color.black.opacity(0.08),
        cell: Color.white.opacity(0.72),
        ringTrack: Color.black.opacity(0.12),
        accent: Color(red: 0, green: 122 / 255, blue: 1),
        accentRing: Color(red: 0, green: 122 / 255, blue: 1).opacity(0.28),
        popover: Color(red: 246 / 255, green: 246 / 255, blue: 246 / 255).opacity(0.96)
    )

    static let dark = MarketPalette(
        text: Color.white.opacity(0.85),
        sec: Color.white.opacity(0.55),
        openText: Color(nsColor: .systemGreen),
        preMarketText: Color(nsColor: .systemOrange),
        afterHoursText: Color(nsColor: .systemBlue),
        faint: Color.white.opacity(0.55),
        divider: Color.white.opacity(0.09),
        dividerStrong: Color.white.opacity(0.09),
        cell: Color.white.opacity(0.07),
        ringTrack: Color.white.opacity(0.18),
        accent: Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255),
        accentRing: Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255).opacity(0.55),
        popover: Color(red: 30 / 255, green: 30 / 255, blue: 32 / 255).opacity(0.97)
    )

    static func palette(for scheme: ColorScheme) -> MarketPalette {
        scheme == .dark ? .dark : .light
    }

    /// Section-header text per state: Apple system colors in TradingView's status
    /// mapping (green open, orange pre-market, blue post-market); Holiday and
    /// Closed stay secondary.
    func stateColor(_ status: SessionStatus) -> Color {
        switch status {
        case .open: openText
        case .preMarket: preMarketText
        case .postMarket: afterHoursText
        case .holiday, .closed: sec
        }
    }
}

import SwiftUI

/// Shared colors. Neutral text and the separator are the system label and
/// separator colors, which the macOS 26 UI kit's label tokens describe (black 85%
/// and 50% light, white 85% and 55% dark) and which follow Increase Contrast;
/// state colors are system colors (`stateColor`).
struct MarketPalette {
    let text: Color
    let sec: Color
    let openText: Color
    let preMarketText: Color
    let afterHoursText: Color
    let separator: Color

    static let light = MarketPalette(
        text: Color(nsColor: .labelColor),
        sec: Color(nsColor: .secondaryLabelColor),
        // Kit light Green #34C759, Orange #FF8D28 and Blue #0088FF measure 2.1, 2.1
        // and 3.3:1 on the light popover; each is darkened just to 4.5:1 for 11pt text.
        openText: Color(red: 0x22 / 255, green: 0x81 / 255, blue: 0x3A / 255),
        preMarketText: Color(red: 0xA8 / 255, green: 0x5D / 255, blue: 0x1A / 255),
        afterHoursText: Color(red: 0x00 / 255, green: 0x71 / 255, blue: 0xD4 / 255),
        separator: Color(nsColor: .separatorColor)
    )

    static let dark = MarketPalette(
        text: Color(nsColor: .labelColor),
        sec: Color(nsColor: .secondaryLabelColor),
        openText: Color(nsColor: .systemGreen),
        preMarketText: Color(nsColor: .systemOrange),
        // Kit dark Blue #0091FF measures 4.43:1 on the dark popover; lightened just to
        // 4.5:1 for 11pt text. Green and orange already clear it.
        afterHoursText: Color(red: 0x05 / 255, green: 0x93 / 255, blue: 0xFF / 255),
        separator: Color(nsColor: .separatorColor)
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

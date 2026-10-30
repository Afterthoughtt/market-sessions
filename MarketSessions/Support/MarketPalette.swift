import SwiftUI

/// Shared colors. Neutral text and the separator are the system label and
/// separator colors, which the macOS 27 UI kit's label tokens describe (black 85%
/// and 50% light, white 85% and 55% dark) and which follow Increase Contrast.
/// State colors are named colors in `Assets.xcassets` (`stateColor`).
struct MarketPalette {
    let text: Color
    let sec: Color
    let openText: Color
    let preMarketText: Color
    let afterHoursText: Color
    let separator: Color
    /// Progress bar track; the fill is `sec`.
    let track: Color

    static let light = MarketPalette(
        text: Color(nsColor: .labelColor),
        sec: Color(nsColor: .secondaryLabelColor),
        openText: Color("OpenText"),
        preMarketText: Color("PreMarketText"),
        afterHoursText: Color("AfterHoursText"),
        separator: Color(nsColor: .separatorColor),
        track: Color.black.opacity(0.08)
    )

    static let dark = MarketPalette(
        text: Color(nsColor: .labelColor),
        sec: Color(nsColor: .secondaryLabelColor),
        openText: Color("OpenText"),
        preMarketText: Color("PreMarketText"),
        afterHoursText: Color("AfterHoursText"),
        separator: Color(nsColor: .separatorColor),
        track: Color.white.opacity(0.08)
    )

    static func palette(for scheme: ColorScheme) -> MarketPalette {
        scheme == .dark ? .dark : .light
    }

    /// Section-header text per state in TradingView's status mapping (green open,
    /// orange pre-market, blue post-market); Holiday and Closed stay secondary.
    /// Each named color is the kit's accent, adjusted where needed to reach 4.5:1 on
    /// the popover and 7:1 with Increase Contrast; values are in DESIGN.md › Colour.
    func stateColor(_ status: SessionStatus) -> Color {
        switch status {
        case .open: openText
        case .preMarket: preMarketText
        case .postMarket: afterHoursText
        case .holiday, .closed: sec
        }
    }
}

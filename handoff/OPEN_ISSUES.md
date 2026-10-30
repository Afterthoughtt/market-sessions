# Open issues

Backlog from the 2026-09-29 production pass. Items name files and symbols rather than line numbers, which drift. Delete an item when it ships.

Out of scope (owner decision 2026-09-29, personal use only): distribution signing and team, notarization, copyright string, App Sandbox.

## Next up

1. **Real-screen checks**, for a local session on the Mini with Computer use (SSH sessions there have no screen access), or owner screenshots:
   - ⌘, opens Settings while the popover is open.
   - The Settings… highlight shows under keyboard focus (System Settings › Keyboard › Keyboard navigation), and whether the system focus ring also draws.
   - VoiceOver moves between section headings.
   - The Christmas-week popover (856pt with all six markets, measured from a render) fits a 13-inch screen; if not, cap the height and scroll the middle.
   - The three-candle menu bar glyph beside Wi‑Fi and Battery: size and weight in light and dark bars, and in the highlighted state.
   - Increase Contrast state colours (`Assets.xcassets`): the compiled catalog holds the high-contrast versions, but a command-line check cannot switch appearance. Check the popover in light and dark with System Settings › Accessibility › Display › Increase Contrast on.
2. **Low priority:** the progress track's fixed 8% black/white (`MarketPalette.track`) ignores Increase Contrast. AppKit's `secondarySystemFill` is black or white at 7.8%; switching to it would let the system handle Increase Contrast, but a command-line check can't confirm it changes there, and the kit cache (`.build/reference/`) is missing, so the kit's token name is unchecked.

## Unverified, check when convenient

- A notification whose trigger passes while the Mac sleeps may be delivered late on wake ("Opens in 5 minutes" hours later). Owner to confirm: 5-minute lead, a market alert due within the hour, sleep through it, wake ~15 minutes later. A `BannerDelegate.willPresent` filter would not help: Apple calls it only while the app is in the foreground, which a menu-bar app rarely is. If confirmed, remove stale delivered banners from the existing wake refresh instead.

## Data refresh (December 2026)

Per `MarketSessions/Resources/README.md`: bundle `market-exceptions-2027.json` for all six markets (whole year only) and the 2027 BLS (CPI, jobs, PPI) and BEA GDP advance dates, which the weekly update cannot read. FOMC, minutes, PCE, retail sales, ECB and BOJ dates already arrive weekly, but bundle their 2027 rows too as the fallback. Until then, market notifications stop at 2026-12-31 and the popover warns once a shown time or the Closures week passes that date.

## Housekeeping

- Xcode 27 has not had "Update to Recommended Settings" accepted (`LastUpgradeCheck = 2660`). If accepted, review the pbxproj diff; the file is hand-maintained.
- The app's UserDefaults still hold a `showsMenuBarCountdown` key from the removed countdown toggle; nothing reads it.

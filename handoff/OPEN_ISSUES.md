# Open issues

Backlog from the 2026-09-29 production pass. Items name files and symbols rather than line numbers, which drift. Delete an item when it ships.

Out of scope (owner decision 2026-09-29, personal use only): distribution signing and team, notarization, copyright string, App Sandbox.

## Next up

1. **Findings from the impeccable critique and audit (2026-10-30), awaiting the owner's pick.** No P0/P1.
   - Accessibility: section headers (`sectionHeader`, "Closures", "Upcoming Events") lack `.accessibilityAddTraits(.isHeader)`. `PopoverRowButtonStyle` highlights on hover only, not on press or keyboard focus. Check that ⌘, fires while the popover is open. 11pt `secondaryLabelColor` text is about 3.9:1 in light mode (DESIGN.md chose it; Increase Contrast fixes it). The progress track is a fixed `black.opacity(0.08)` that ignores Increase Contrast.
   - Layout: the popover's `VStack` has no height cap or scrolling, so with every section showing it may run past a small or scaled screen (estimated, not measured).
   - What changes next: Pre-Market, After Hours and Closed rows show the next regular open (`SessionResolver`), not the earlier change (After Hours ending, Pre-Market starting), as DESIGN.md specifies; the critique suggests adding the earlier change.
   - Closures: the four-row cap can hide every full-day closure (Christmas week); see the open A/B/C layout question.
   - Smaller: a green "Open" header over "No markets open"; "Daily Close" has no tooltip saying midnight UTC; early closes shown in the display zone can land on a surprising date (add market-local time to the tooltip); the notification plan is rebuilt every minute and `DateFormatter`s are made in view bodies.

## Unverified, check when convenient

- Increase Contrast state colours (`Assets.xcassets`): the compiled catalog holds the high-contrast versions, but a command-line check cannot switch appearance; confirm with owner screenshots of the popover in light and dark with System Settings › Accessibility › Display › Increase Contrast on.

- The three-candle menu bar glyph has not been seen in the real bar: check its size and weight against Wi‑Fi and Battery, light and dark bars, and the highlighted state.

- A notification whose trigger passes while the Mac sleeps may be delivered late on wake ("Opens in 5 minutes" hours later). Owner to confirm: 5-minute lead, a market alert due within the hour, sleep through it, wake ~15 minutes later. A `BannerDelegate.willPresent` filter would not help: Apple calls it only while the app is in the foreground, which a menu-bar app rarely is. If confirmed, remove stale delivered banners from the existing wake refresh instead.

## Data refresh (December 2026)

Per `MarketSessions/Resources/README.md`: bundle `market-exceptions-2027.json` for all six markets (whole year only) and the 2027 BLS (CPI, jobs, PPI) and BEA GDP advance dates, which the weekly update cannot read. FOMC, minutes, PCE, retail sales, ECB and BOJ dates already arrive weekly, but bundle their 2027 rows too as the fallback. Until then, market notifications stop at 2026-12-31 and the popover warns once a shown time or the Closures week passes that date.

## Housekeeping

- Xcode 27 has not had "Update to Recommended Settings" accepted (`LastUpgradeCheck = 2660`). If accepted, review the pbxproj diff; the file is hand-maintained.
- The app's UserDefaults still hold a `showsMenuBarCountdown` key from the removed countdown toggle; nothing reads it.

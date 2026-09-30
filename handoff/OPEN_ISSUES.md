# Open issues

Backlog from the 2026-09-29 production pass. Items name files and symbols rather than line numbers, which drift. Delete an item when it ships.

Out of scope (owner decision 2026-09-29, personal use only): distribution signing and team, notarization, app icon, copyright string, App Sandbox.

## Next up

1. **Coverage line noise.** `UpcomingEconomicEvents.coverageGap` treats fewer than four events as an infinite horizon, so selecting only sparse kinds (Fed Chair) shows "Central bank dates bundled through …" permanently; coverage is also per category, not per selected kind.
2. **Holiday eve.** `SessionResolver` marks Holiday only when now's canonical date is the holiday, so the evening before (e.g. CME Thursday after 17:00 CT before a Good-Friday-style closure) reads Closed.
3. **Menu bar pill as custom SF Symbols, with an outline trace.** Owner decisions 2026-09-30: rebuild `MenuBarPill` as custom symbols (six codes, outlined; the traced outline replaces the filled pill) in a new asset catalog, and trace the time left around the pill's outline while a market is open. The San Francisco font licence allows the font only for mock-ups, so letters come from exported SF Symbols templates, not SF Pro outlines. Exports are in `symbols export/` (gitignored): `c d e g h k l m n o s t y` as `.square` (letter is its own path, three weights with matching point structure, so Bold interpolates), `c.square.fill` (cut-out encoding), plus owner extras. The `.square` enclosure carries `data-clipstroke-keyframes` (Draw data, starting at top centre and running clockwise) on a rounded-rectangle ring, reusable for a stretched pill. The trace (owner pick A, DESIGN.md › Menu bar label) is built by trimming the stroke in the existing `ImageRenderer` pipeline and awaits an owner screenshot while a market is open; the custom-symbol rebuild remains. Variable Draw findings (2026-09-30): it is switched on per layer in the SF Symbols app (WWDC25 session 337, "What's new in SF Symbols 7"), and the undrawn part stays at 0.3 opacity, the same as the trace's track. How a template encodes it is undocumented (strings in the SF Symbols app suggest a `-sfsymbols-variable-draw` style property), and none of the exports carry it, so the pill symbols would be authored in the app. Its guide points would run counter-clockwise from 12 o'clock, so that a value equal to the time left keeps the trace direction. SwiftUI `Image(_:variableValue:)` with `.symbolVariableValueMode(.draw)` and AppKit `NSImage.SymbolConfiguration(variableValueMode:)` are macOS 26.0 SDK API; the AppKit configuration clears `isTemplate`, which must be set again.

## Unverified, check when convenient

- A notification whose trigger passes while the Mac sleeps may be delivered late on wake ("Opens in 5 minutes" hours later). Owner to confirm: 5-minute lead, a market alert due within the hour, sleep through it, wake ~15 minutes later. A `BannerDelegate.willPresent` filter would not help: Apple calls it only while the app is in the foreground, which a menu-bar app rarely is. If confirmed, remove stale delivered banners from the existing wake refresh instead.
- Menu bar pill, seen only as a traced pill in a dark bar (owner screenshots 2026-09-30). Not yet seen: the whole outline (counting to an open), a light bar, Increase Contrast, the highlighted item while the popover is open, and the item under VoiceOver or keyboard (Control-F8).

## Data refresh (December 2026)

Per `MarketSessions/Resources/README.md`: bundle `market-exceptions-2027.json` for all six markets (whole year only) and 2027 BLS/BEA/Census releases plus FOMC minutes. Until then, market notifications stop at 2026-12-31 and the popover warns once a shown time passes that date.

## Housekeeping

- Xcode 27 has not had "Update to Recommended Settings" accepted (`LastUpgradeCheck = 2660`). If accepted, review the pbxproj diff; the file is hand-maintained.
- The design canvas (claude.ai artifact "Menu Bar Explorations", board H) still shows After Hours with a filled pill; the app correctly outlines it.

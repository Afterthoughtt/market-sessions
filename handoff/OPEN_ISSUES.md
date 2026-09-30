# Open issues

Backlog from the 2026-09-29 production pass. Items name files and symbols rather than line numbers, which drift. Delete an item when it ships.

Out of scope (owner decision 2026-09-29, personal use only): distribution signing and team, notarization, app icon, copyright string, App Sandbox.

## Next up

1. **Coverage line noise.** `UpcomingEconomicEvents.coverageGap` treats fewer than four events as an infinite horizon, so selecting only sparse kinds (Fed Chair) shows "Central bank dates bundled through …" permanently; coverage is also per category, not per selected kind.
2. **Holiday eve.** `SessionResolver` marks Holiday only when now's canonical date is the holiday, so the evening before (e.g. CME Thursday after 17:00 CT before a Good-Friday-style closure) reads Closed.
3. **Menu bar pill as custom SF Symbols.** Owner asked (2026-09-30) to rebuild `MenuBarPill` as custom symbols so the system sizes and aligns it. The San Francisco font licence allows the font only for mock-ups, so the code letters cannot be SF Pro outlines baked into an asset; the letters available as SF Symbols (`l.square.fill` and so on) are the licensed route. Waiting on the owner's choice of route; see the canvas board "Menu bar and Settings".

## Unverified, check when convenient

- A notification whose trigger passes while the Mac sleeps may be delivered late on wake ("Opens in 5 minutes" hours later). Owner to confirm: 5-minute lead, a market alert due within the hour, sleep through it, wake ~15 minutes later. A `BannerDelegate.willPresent` filter would not help: Apple calls it only while the app is in the foreground, which a menu-bar app rarely is. If confirmed, remove stale delivered banners from the existing wake refresh instead.
- Not yet seen in the real menu bar: the outlined pill (previews draw it correctly; the owner screenshot showed the filled state).

## Data refresh (December 2026)

Per `MarketSessions/Resources/README.md`: bundle `market-exceptions-2027.json` for all six markets (whole year only) and 2027 BLS/BEA/Census releases plus FOMC minutes. Until then, market notifications stop at 2026-12-31 and the popover warns once a shown time passes that date.

## Housekeeping

- Xcode 27 has not had "Update to Recommended Settings" accepted (`LastUpgradeCheck = 2660`). If accepted, review the pbxproj diff; the file is hand-maintained.
- The design canvas (claude.ai artifact "Menu Bar Explorations", board H) still shows After Hours with a filled pill; the app correctly outlines it.

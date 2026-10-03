# Open issues

Backlog from the 2026-09-29 production pass. Items name files and symbols rather than line numbers, which drift. Delete an item when it ships.

Out of scope (owner decision 2026-09-29, personal use only): distribution signing and team, notarization, app icon, copyright string, App Sandbox.

## Next up

1. **Coverage line noise.** `UpcomingEconomicEvents.coverageGap` treats fewer than four events as an infinite horizon, so selecting only sparse kinds (Fed Chair) shows "Central bank dates bundled through …" permanently; coverage is also per category, not per selected kind.
2. **Holiday eve.** `SessionResolver` marks Holiday only when now's canonical date is the holiday, so the evening before (e.g. CME Thursday after 17:00 CT before a Good-Friday-style closure) reads Closed.
3. **DESIGN.md audit against the macOS 27 kit, the macOS Development plugin and the HIG (2026-09-30; owner wants all of it implemented).** Matches the kit, keep: label tokens (black 0.85/0.50, white 0.85/0.55), accent hexes (#34C759/#30D158, #FF8D28/#FF9230, #0088FF/#0091FF), type sizes (15 Semibold = Title 3 Emphasized, 13 = Body, 11 = Subheadline), Settings form rows (13/11 Medium, kit Forms), menu-item highlight (Hover + Key: #0069F9, white label, 8pt corners), 11pt menu separator, 13pt Semibold status items. Findings:
   - a. **Popover versus menu (decision for the owner).** HIG The menu bar: "Display a menu — not a popover — when people click your menu bar extra", unless the functionality is too complex for a menu. DESIGN.md specifies a popover (`.menuBarExtraStyle(.window)`) with no recorded reason. Either record the exception and its reason (two-line rows, right-aligned times, state-coloured section headers), or move to `.menu`.
   - b. **Popover material and corners.** DESIGN.md › Popover says "NSVisualEffectView .popover (or .glassEffect on macOS 26)" and corner radius 14. The macOS 27 kit's popover (Popovers page `207:14483`) is Liquid Glass with 20pt corners, and the window is system-drawn anyway. Rewrite it as "system window material and corners, nothing custom". The code applies no material, so this is a doc fix only; confirm it in `SessionsPopover`.
   - c. **Semantic text styles (plugin `design/references/visual-and-materials.md`: fixed sizes need a reason).** Every view uses `.font(.system(size:))`. Move to `.title3.weight(.semibold)`, `.body`, `.subheadline` (11 Semibold section headers: `.subheadline.weight(.semibold)`), keeping `.monospacedDigit()`, and state the text styles in DESIGN.md. The Settings rows' 13/11 Medium has no named style; keep it with the kit Forms page (`207:14477`) as the reason. Check the kit's text styles on the Text Styles page (`0:962`).
   - d. **State colours and Increase Contrast (decision for the owner on the approach).** `MarketPalette` hard-codes light #22813A/#A85D1A/#0071D4 and dark #0593FF, which do not adapt to Increase Contrast. The plugin says to use asset-catalog named colours with light, dark and high-contrast variants when system colours do not fit. The kit also has vibrant accents for text on materials (Colors page `0:687`, "Accents - Vibrant": light #26BF4D/#F58625/#0078F0, dark #3BDB63/#FF9E33/#0A99FF) that DESIGN.md never considered; measure them on the popover before choosing. An asset catalog means new pbxproj entries (five places).
   - e. **Stale or contradictory text in DESIGN.md.** The title and intro ("Turn 7a reference + 10a label", "static design reference, fixed snapshot"). Popover › Footer says Settings holds "About", which does not exist. Type says "regular/semibold only", but Medium and Bold are used. The General tab height (374pt) predates removing the countdown row; re-measure it. The Settings… row is 32pt while citing the kit menu item (24pt); decide and record. The Files line says popover.html shows the current label; it does not. The `MarketPalette` doc comment still cites the macOS 26 kit.
   - After implementing: update the design canvas boards (Tokens, Popover anatomy, Findings) to the macOS 27 kit, and run design-review and accessibility-audit.

## Unverified, check when convenient

- A notification whose trigger passes while the Mac sleeps may be delivered late on wake ("Opens in 5 minutes" hours later). Owner to confirm: 5-minute lead, a market alert due within the hour, sleep through it, wake ~15 minutes later. A `BannerDelegate.willPresent` filter would not help: Apple calls it only while the app is in the foreground, which a menu-bar app rarely is. If confirmed, remove stale delivered banners from the existing wake refresh instead.

## Data refresh (December 2026)

Per `MarketSessions/Resources/README.md`: bundle `market-exceptions-2027.json` for all six markets (whole year only) and 2027 BLS/BEA/Census releases plus FOMC minutes. Until then, market notifications stop at 2026-12-31 and the popover warns once a shown time passes that date.

## Housekeeping

- Xcode 27 has not had "Update to Recommended Settings" accepted (`LastUpgradeCheck = 2660`). If accepted, review the pbxproj diff; the file is hand-maintained.
- The app's UserDefaults still hold a `showsMenuBarCountdown` key from the removed countdown toggle; nothing reads it.
- `.build/reference/figma-macos26.json` (the old macOS 26 kit) sits beside the macOS 27 cache; delete it once nothing cites the 26 kit (the `MarketPalette` comment, the canvas heading "× Apple macOS 26 kit").

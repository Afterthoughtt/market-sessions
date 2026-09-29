# Open issues

Backlog from the 2026-09-29 production pass. Items name files and symbols rather than line numbers, which drift. Delete an item when it ships.

Out of scope (owner decision 2026-09-29, personal use only): distribution signing and team, notarization, app icon, copyright string, App Sandbox.

## Next up

3. **One event is formatted three ways.** The row tooltip (`DateFormatter.timeStyle .short`) and the Settings next-event subtitle (`Date.FormatStyle .shortened`) keep Foundation's narrow U+202F before AM/PM; the popover and notifications replace it (`MarketDateFormatting.time`). The approximation marker is "≈", "(approximate announcement time)" and "(approx.)" in different places. Fix: route both through `MarketDateFormatting` and keep one marker string on `EconomicEventKind`.
4. **CME maintenance shows before a full holiday.** `SessionResolver` keeps the 16:00–17:00 CT maintenance gap on the day before a full CME holiday that has no early close. The row reads "Break · Opens …" for an hour, then Closed. `NotificationPlanner` already filters this (maintenance must sit between two active periods); apply the same rule in the resolver. No 2026 date triggers it; a future Good Friday would.
5. **Launch at Login errors are swallowed.** `MarketSessionsModel.setLaunchAtLogin` uses `try?`, so a failed register/unregister just snaps the toggle back. Fix: surface the error in the row subtitle.

## Unverified, check when convenient

- A notification whose trigger passes while the Mac sleeps may be delivered late on wake ("Opens in 5 minutes" hours later). Possible fix: in `BannerDelegate.willPresent`, suppress banners whose trigger date is well past. Confirm the behavior first.
- A per-event title (e.g. "Jackson Hole keynote — Fed Chair", 32 characters) may truncate next to "Tomorrow 10:00 AM" in the 340pt popover. The ≤30-character test covers kind titles only. No such event is bundled now.
- macOS 27 changed bordered `Picker` rendering (no longer `NSPopUpButton`). Check the time zone and notification lead-time pickers in Settings.
- Not yet seen on screen: the Settings › General pane at its new 340pt height (the "Show Time in Menu Bar" toggle was added) and the outlined menu bar pill.
- The ECB 14:15 CET decision time is a bundle convention; the dates are verified, the time is not (the ECB pages need JavaScript).

## Data refresh (December 2026)

Per `MarketSessions/Resources/README.md`: bundle `market-exceptions-2027.json` for all six markets (whole year only) and 2027 BLS/BEA/Census releases plus FOMC minutes. Until then, market notifications stop at 2026-12-31 and the popover warns once a shown time passes that date.

## Housekeeping

- Xcode 27 has not had "Update to Recommended Settings" accepted (`LastUpgradeCheck = 2660`). If accepted, review the pbxproj diff; the file is hand-maintained.
- The design canvas (claude.ai artifact "Menu Bar Explorations", board H) still shows After Hours with a filled pill; the app correctly outlines it.

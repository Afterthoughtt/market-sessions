# Market Sessions — design handoff (Turn 7a reference + 10a label)

Static design reference only. Data shown is a fixed snapshot (Thu 6:09 PM PDT); wire real state, event feed and holiday data in code.

## Files
- popover.html — the popover at 340pt and the menu-bar label, inline-styled, no dependencies. Open in a browser.

## Popover
- Width 340pt. Height = content. Material: NSVisualEffectView .popover (or .glassEffect on macOS 26). No other material, card or ring inside; the only colour is the state-coloured section header text.
- Padding 14pt sides/top, 4pt bottom. Corner radius 14 (system default is fine).
- Header: title "Market Sessions" 15 semibold; subtitle = weekday, 13 secondary. Right column: "Daily Close in 22h 51m" 13 secondary (countdown value semibold primary, tabular) on the weekday's baseline; only when Settings overrides the zone, "Time · EST" 11 secondary above it (owner decision 2026-09-29: the system zone needs no label).
- Sections: Open, Pre-Market, After Hours, Holiday, Closed (empty ones omitted). Section header: the state name 11 semibold in the state colour (owner decision 2026-09-30); 16pt above, 2pt below. No hairlines between rows: section headers and whitespace do the grouping (owner decision 2026-09-29).
- Market row, 40pt (owner decision 2026-09-30, design C "time left first"): name 13 primary over the next change 11 secondary tabular ("Closes 11:30 PM", "Opens Wed 6:30 AM", "Reopens 3:00 PM" during a lunch recess or CME maintenance); right, the time until that change as the main value: while Open "9m left" (13 semibold primary + 11 secondary "left"), otherwise "in 7h 9m" (11 secondary "in" + 13 regular, primary for Pre-Market and After Hours, secondary for Holiday and Closed). Open rows add a bar under the row (owner decision 2026-10-22, restoring the 2026-09-29 bar): the kit's Small determinate bar, 6pt tall and fully rounded, track 8% black (8% white in dark), fill the secondary label colour, filling from the start of the uninterrupted open run (`ResolvedSession.activeStart`; it restarts after a lunch recess or maintenance, not at a contiguous auction) toward the close shown, never narrower than a 6pt dot once started; 6pt below it. Other rows have no bar and no row tint. Sort each section by soonest change. The value is 13pt, the kit's detail-label size (owner decision 2026-09-30, replacing 17pt, which outsized the 15pt title).
- Each selected market appears in exactly one section.
- Upcoming events: header "Upcoming events"; always next 4, no disclosure. Row 24pt: name 13 primary, right 13 secondary date "Fri, Sep 4"; inside 24h the right side becomes "Tomorrow 7:00 AM" in semibold primary. Short names (Nonfarm Payrolls, CPI, FOMC Decision…). Which events to show is a Settings preference.
- Footer: full-width hairline (system separator colour, bleeds to popover edge) 5pt below the last row (the kit's 11pt menu separator), then one 32pt row "Settings…" 13 medium primary. On hover it takes the kit's menu-item highlight: accent fill, white label, 8pt corners (owner decision 2026-09-30). Opens a Settings window holding Launch at Login, event selection, holiday-data note, About, Quit. No other controls in the popover.
- Warning state only: if bundled holiday data has expired, one 11pt secondary text line above the Settings hairline.

## Type (macOS scale, regular/semibold only)
15 title · 13 body, trailing times, and header readouts (the kit's form and menu detail labels are 13pt; owner found 10–11pt too small, 2026-09-29) · 11 section headers, subtitles, and footnote lines. Tabular figures on every time and countdown.

## Colour
Primary text, secondary text and the hairline are the system label, secondary label and separator colours, so they follow Increase Contrast (owner decision 2026-09-30, replacing fixed opacities). The kit's label tokens give their values: black at 0.85 / 0.50 in light, white at 0.85 / 0.55 in dark. State colours are Apple system colours in TradingView's status mapping: Open green, Pre-Market orange, After Hours blue, Holiday and Closed secondary. Dark mode uses NSColor systemGreen and systemOrange (Increase Contrast applies) and #0593FF for After Hours: the kit's dark Blue #0091FF measured 4.43:1 on the dark popover, so it is lightened just to 4.5:1 (owner decision 2026-09-30); light mode darkens the kit's light values just to 4.5:1 for 11pt text on the light popover: #22813A, #A85D1A, #0071D4 (kit #34C759, #FF8D28, #0088FF measure 2.1, 2.1, 3.3:1). Owner decision 2026-09-30.

## Menu-bar label (10a)
Superseded by the owner decision under "Menu bar label" below: a fixed glyph.

## Owner decisions (amend the sections above; these win on conflict)

### Sessions (six available, all shown by default)

| Code | Name | Canonical zone | Notes |
| --- | --- | --- | --- |
| `NY` | New York | `America/New_York` | 9:30–16:00 weekdays; pre-market 4:00–9:30, post-market 16:00–20:00 |
| `CME` | CME Futures | `America/Chicago` | Equity-index session: Sun–Fri 17:00–16:00 next day; Mon–Thu 16:00–17:00 break; no estimate marker |
| `LDN` | London | `Europe/London` | 8:00–16:30 weekdays |
| `TYO` | Tokyo | `Asia/Tokyo` | 9:00–11:30, 12:30–15:30; lunch recess |
| `HKG` | Hong Kong | `Asia/Hong_Kong` | 9:30–12:00, 13:00–16:00; recess; closing auction 16:00–16:10 (outer bound) |
| `SHG` | Shanghai | `Asia/Shanghai` | 9:30–11:30, 13:00–14:57; recess; closing auction 14:57–15:00 |

Schedules are defined in canonical IANA zones. Display time defaults to the system zone; Settings can override it. Display-zone changes never move schedule instants or the UTC daily close. Holidays and early closes come from the bundled exceptions file (see `MarketSessions/Resources/README.md`): holiday occurrences are dropped, sessions straddling an early close are clamped, same-day remnants after it are dropped, and overnight re-opens (CME's evening session after a holiday halt) are kept.

### States and appearance

Five market states, TradingView's statuses without Overnight (no bundled market trades overnight): **Open, Pre-Market, After Hours, Holiday, Closed** (owner decision 2026-09-30, replacing Break). Trading and contiguous auctions resolve to Open; pre-open windows to Pre-Market (New York 4:00–9:30 ET early trading; London 7:50–8:00 opening auction call; Tokyo 8:00–9:00 order acceptance; Hong Kong 9:00–9:30 pre-opening auction; Shanghai 9:15–9:30 opening call auction plus the gap to continuous trading) and New York's 16:00–20:00 ET late session to After Hours (exchange-published hours, verified 2026-09-05, see `finance-market-sessions-reference.md`). A lunch recess or CME's maintenance hour is Closed, reopening at the next session (TradingView has no pause status). A closed market whose canonical date is a bundled holiday is Holiday. Only Open counts as active. Transition readouts say Opens/Closes/Reopens with the scheduled boundary and no estimate marker. Colours: see Colour above.

### Popover (340 wide, height fits content)

1. Header — title and local weekday; `Time · <zone>` only for a Settings override; UTC "Daily Close in Xh Ym".
2. Open — active markets ordered by nearest close: close time and time left.
3. Pre-Market, After Hours, Holiday, then Closed — ordered by nearest change: open time and time until it. Omit empty sections. Each selected market appears once. Rows are non-interactive.
4. Upcoming Events — the next four of the selected kinds, no disclosure. Compact names (U.S. Jobs Report, FOMC Decision); full description and exact local date/time in tooltips and accessibility labels. Preserve per-event titles (Jackson Hole keynote). Inside 24 hours emphasize Today/Tomorrow + local time; while live show Live. BOJ carries no approximation marker (owner decision 2026-09-29); its stored 12:00 JST is noted only in the Settings tooltip. When nothing selected remains, say the bundled schedule has none. When a selected category's bundled dates end before the last shown row, one 11pt secondary line says so ("U.S. release dates bundled through Dec 23, 2026"); Settings rows past their category's coverage read "Not in bundled schedule".
5. Footer — holiday-data warning only when unavailable or expired, or when a shown open/close falls after the data ends ("Holiday data ends Dec 31, 2026; later times assume regular hours"), then a full-width Settings row (⌘,) with the kit's menu-item hover.

### Menu bar label

A fixed glyph that does not convey market state (owner decision 2026-10-02); the popover carries state and times. The glyph is four outlined bars sharing walls, drawn off one straight horizontal line through the middle: two bars hang below it (the first deeper), two rise above it (the last taller) (owner pick "Four bars, outlined" on the design canvas board "Menu bar icon: bar options", 2026-10-21). Geometry in a 16pt box: 1.2pt line with round caps and joins (owner choice; Apple's menu bar symbols measure 1.45pt), bars 3.7pt wide, ends at 14.2, 11, 5 and 1.8pt from the top. A template image so the system tints it. Tooltip and accessibility label: the next-to-change session's full name, status, and "Closes 1:00 PM", or "Market Sessions — choose markets in Settings" with no markets selected.

### App icon

The menu bar glyph's shape, made in Icon Composer by the owner (decision 2026-10-21). Source layers in `handoff/app-icon/`: 1024 canvas, black, no background, the glyph about 60% of the canvas width and centred (the macOS 27 kit has no app icon grid); `1-bars.svg` keeps the menu bar's line weight, `1-bars-heavy.svg` is 1.5× heavier for small sizes. Lines are filled shapes, not strokes, so Icon Composer needs no SVG stroke support.

### Settings

Native Settings scene, four tabs, each sized to its content with no scrolling (owner decision 2026-09-30; measured at 520 wide: General 374 before its Show Countdown row was removed on 2026-09-30, not re-measured; Markets 362, Events 785, Notifications 227pt) (General `gearshape`, Markets `globe.badge.clock`, Events `calendar.badge.clock`, Notifications `bell`; both badge symbols are available from macOS 26.0). Error subtitles name the cause and the fix. Rows follow the kit form pattern: 13pt Medium title, 11pt Medium secondary subtitle, trailing control or detail label aligned to the title line (the grouped Form's default; decision 2026-09-29); explanatory text lives in subtitles and section footers, not loose rows. General: Time Zone pop-up (North American zones plus UTC, stored as IANA identifiers, System by default, live zone name and offset in the subtitle), Holiday Coverage detail row, then Launch at Login and Quit. Markets: one row per session with a Notify checkbox, then the switch that shows it in the popover and menu bar (owner decision 2026-09-30: each market and event kind appears once in Settings). Events: U.S. Releases and Central Banks groups with the same Notify checkbox and Show switch per kind, each row's subtitle showing its next bundled date, footer stating the coverage per group. Selections apply immediately and persist in `MarketPreferences`. Turning off every market is allowed; turning off every event kind hides the section. Notifications: Lead Time pop-up (At the time, 5, 15, 30 minutes before) and the test-notification or permission row; the footer points to the Notify checkboxes. Notify is off by default and independent of Show, so a hidden market can still notify. While macOS has notifications turned off, the Markets and Events footers say so. A market notifies at the first open and final close of its trading day in the canonical zone (lunch recesses and CME's daily maintenance gap stay silent, holidays and early closes already applied); an event notifies at its scheduled start. Notifications are local `UNUserNotificationCenter` requests planned deterministically from the bundled schedule, authorization is requested on the first toggle, and a denied state shows one row linking to System Settings › Notifications. Body text uses the display zone.

### Non-features

No network entitlement or code, no dependencies, no telemetry, no accounts. If live fetching is ever added it is a separate phase: sandboxed XPC helper, `federalreserve.gov` only, weekly, off by default. Excluded event kinds: jobless claims, ISM, JOLTS, consumer confidence, options expiries.

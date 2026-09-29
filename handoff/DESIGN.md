# Market Sessions — design handoff (Turn 7a reference + 10a label)

Static design reference only. Data shown is a fixed snapshot (Thu 6:09 PM PDT); wire real state, event feed and holiday data in code.

## Files
- popover.html — the popover at 340pt and the menu-bar label, inline-styled, no dependencies. Open in a browser.

## Popover
- Width 340pt. Height = content. Material: NSVisualEffectView .popover (or .glassEffect on macOS 26). No other material, card, ring, or accent colour inside.
- Padding 14pt sides/top, 4pt bottom. Corner radius 14 (system default is fine).
- Header: title "Market Sessions" 15 semibold; subtitle = weekday, 11 secondary. Right column, 10pt secondary: "Your time · PDT" over "Daily Close in 22h 51m" (countdown value 10 semibold primary, tabular).
- Sections: "Open" then "Closed". Section header 11 semibold secondary, 16pt above, 2pt below. Rows separated by 1pt hairline at 7% black. Sections separated by whitespace only.
- Open row: name 13 regular primary; second line = 3pt scrubber (track 8% black, fill 50% black, radius 1.5, fill = elapsed fraction) + "Closes 7:30 PM" 11 secondary tabular. Row padding 8 top / 10 bottom, 7 between lines. Sort by soonest close.
- Closed row: 32pt; name 13 primary left, "Opens 6:30 PM" 11 secondary tabular right. Sort by soonest open. Filter rule: a session appears in exactly one section.
- Upcoming events: header "Upcoming events"; always next 4, no disclosure. Row 32pt: name 13 primary, right 11 secondary date "Fri, Sep 4"; inside 24h the right side becomes "Tomorrow 7:00 AM" in semibold primary. Short names (Nonfarm Payrolls, CPI, FOMC Decision…). Which events to show is a Settings preference.
- Footer: full-width hairline (8% black, bleeds to popover edge), then one 32pt row "Settings…" 13 primary. Opens a Settings window holding Launch at Login, event selection, holiday-data note, About, Quit. No other controls in the popover.
- Warning state only: if bundled holiday data has expired, one 11pt secondary text line above the Settings hairline.

## Type (macOS scale, regular/semibold only)
15 title · 13 body / headers-of-things · 11 meta and section headers · 10 header readouts. Tabular figures on every time and countdown.

## Colour
Primary text rgba(0,0,0,0.85); secondary rgba(0,0,0,0.55); hairline rgba(0,0,0,0.07–0.08). No green, no blue, in the popover; the only color is the extended-hours row tint below. Dark mode: white at 0.92 / 0.50 / 0.09 respectively.

## Menu-bar label (10a)
Superseded 2026-09-29 by the owner decision under "Menu bar label" below: a code pill plus the clock time of the next change. The earlier text-only label (`LDN closes 2h 14m`) and the status dot before it were dropped.

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

Five market states: **Open, Pre-Market, After Hours, Break, Closed**. Trading and contiguous auctions resolve to Open; pre-open windows to Pre-Market (New York 4:00–9:30 ET early trading; London 7:50–8:00 opening auction call; Tokyo 8:00–9:00 order acceptance; Hong Kong 9:00–9:30 pre-opening auction; Shanghai 9:15–9:30 opening call auction plus the gap to continuous trading) and New York's 16:00–20:00 ET late session to After Hours (exchange-published hours, verified 2026-09-05, see `finance-market-sessions-reference.md`); recess and maintenance to Break; overnight/weekend closures to Closed. Only Open counts as active for rings and bars. Transition readouts say Opens/Closes with the scheduled boundary and no estimate marker. The popover is monochrome on the system material except the extended-hours tint: Pre-Market rows carry a vertical system Orange tint and After Hours rows a vertical system Indigo tint (kit Colors → Accents; NSColor supplies the light/dark value), 22%→10% top to bottom on the kit's 24pt / 8pt-radius menu-item highlight geometry. Break and Closed rows stay untinted. Neutral values follow the macOS 26 kit tokens. No cards, other accent colors, or status badges.

### Progress

Bars **drain to the close shown**: full at the start of the uninterrupted trading period (`activePeriodStart`), empty at the next close (`transition.date`). Restart after lunch or maintenance, not at a contiguous auction. Bars have equal full-row track widths below the name/time line.

### Popover (340 wide, height fits content)

1. Header — title and local weekday; `Your time · <zone>` (or `Time · <zone>` for an override); UTC "Daily Close in Xh Ym".
2. Open — active markets ordered by nearest close, with local close time and a draining bar.
3. Pre-Market, After Hours, Break, then Closed — ordered by nearest open, with local Opens time. Omit empty sections. Each selected market appears once. Rows are non-interactive.
4. Upcoming Events — the next four of the selected kinds, no disclosure. Compact names (U.S. Jobs Report, FOMC Decision); full description and exact local date/time in tooltips and accessibility labels. Preserve per-event titles (Jackson Hole keynote). Inside 24 hours emphasize Today/Tomorrow + local time; while live show Live. BOJ dates, times and Live carry the approximation marker "≈ " as a prefix, the same string in tooltips, Settings and notifications. When nothing selected remains, say the bundled schedule has none. When a selected category's bundled dates end before the last shown row, one 11pt secondary line says so ("U.S. release dates bundled through Dec 23, 2026"); Settings rows past their category's coverage read "Not in bundled schedule".
5. Footer — holiday-data warning only when unavailable or expired, or when a shown open/close falls after the data ends ("Holiday data ends Dec 31, 2026; later times assume regular hours"), then a full-width Settings row (⌘,) with the kit's menu-item hover.

### Menu bar label

The next-to-change session's code in a rounded pill, then the local clock time of that change: `[LDN] 8:30 AM`, `[TYO] Sun 5:00 PM` (decision 2026-09-29, canvas board H). A filled pill counts to a close (Open); an outlined pill counts to an open (Pre-Market, After Hours, Break, Closed — After Hours counts to the next open, as its popover row does). The pill is a template image so the system tints it for light and dark bars, the pressed state and the Liquid Glass tint; the filled pill's code is knocked out to transparent. Pill is 15pt tall in a 16pt glyph box with an 11pt Bold code, level with the menu bar's battery-with-percentage badge by eye; continuous corners at about 0.3 × height (4.5pt), the ratio of SF Symbols `battery.100percent` at the menu-bar configuration (13pt Semibold); 1.3pt outline, that configuration's symbol stroke. 1.5pt of transparent trailing padding brings the pill-to-time ink gap to ~5pt, matching Apple's Weather item (glyph + temperature) beside it. Sizing to `a.square.fill` (12pt) was tried 2026-09-29 and rejected: shorter than the digits beside it. The time is native text at the kit's 13pt Semibold with tabular figures and uses the clock's format: a full space before AM/PM (Foundation's narrow U+202F is replaced app-wide), minutes always, weekday when not today, the system's 12/24-hour setting. Settings › General › Show Time in Menu Bar (default on) leaves only the pill when off, like Battery's Show Percentage. Tooltip and accessibility label: full name, status, and "Closes 1:00 PM". With no markets selected, keep a clock glyph so Settings stays reachable.

### Settings

Native Settings scene, four tabs sized per tab. Rows follow the kit form pattern: 13pt Medium title, 11pt Medium secondary subtitle, trailing control or detail label; explanatory text lives in subtitles and section footers, not loose rows. General: Time Zone pop-up (North American zones plus UTC, stored as IANA identifiers, System by default, live zone name and offset in the subtitle), Holiday Coverage detail row, then Launch at Login and Quit. Markets: one toggle per session. Events: U.S. Releases and Central Banks groups, each row's subtitle showing its next bundled date, footer stating the coverage per group. Selections apply immediately and persist in `MarketPreferences`. Turning off every market is allowed; turning off every event kind hides the section. Notifications: Lead Time pop-up (At the time, 5, 15, 30 minutes before), then Markets and the two event groups as toggles, all off by default and independent of what the popover shows; the form scrolls at the Events tab height. A market notifies at the first open and final close of its trading day in the canonical zone (lunch recesses and CME's daily maintenance gap stay silent, holidays and early closes already applied); an event notifies at its scheduled start, BOJ with the approximation marker. Notifications are local `UNUserNotificationCenter` requests planned deterministically from the bundled schedule, authorization is requested on the first toggle, and a denied state shows one row linking to System Settings › Notifications. Body text uses the display zone.

### Non-features

No network entitlement or code, no dependencies, no telemetry, no accounts. If live fetching is ever added it is a separate phase: sandboxed XPC helper, `federalreserve.gov` only, weekly, off by default. Excluded event kinds: jobless claims, ISM, JOLTS, consumer confidence, options expiries.

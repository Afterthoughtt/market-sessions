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
A status dot, the next-to-change session's 3-letter code, and a countdown to that change (`● LDN 2h 14m`, the popover's compact duration) as native status-item text at 13pt Semibold with tabular figures (kit menu bar trailing label, the same style as the clock). The dot is an 8pt disc while the countdown runs to a close and an 8pt ring (1.5pt stroke) while it runs to an open, centred in the 16pt menu-bar glyph box, following Apple's own extras: state in a glyph variant, the value in text, no verb. A full-size SF Symbol `circle.fill` at the 13pt glyph configuration was tried and rejected as a blot (2026-09-07). Tooltip: full name + status + "Closes 7:30 PM".

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
4. Upcoming Events — the next four of the selected kinds, no disclosure. Compact names (U.S. Jobs Report, FOMC Decision); full description and exact local date/time in tooltips and accessibility labels. Preserve per-event titles (Jackson Hole keynote). Inside 24 hours emphasize Today/Tomorrow + local time; while live show Live. BOJ times carry the approximation marker. When nothing selected remains, say the bundled schedule has none.
5. Footer — holiday-data warning only when unavailable or expired, then a full-width Settings row (⌘,) with the kit's menu-item hover.

### Menu bar label

The dot is rendered via `ImageRenderer` to a template `NSImage` at the sharpest display's scale (SwiftUI shapes do not draw in a `MenuBarExtra` label), followed by one native `Text` (code, space, compact countdown) with `monospacedDigit()` at 13pt Semibold; the system sets the glyph gap and the countdown ticks with the model's minute clock. The dot keys off the transition verb, not the Open state, so After Hours counting to its close stays filled. The earlier progress ring was dropped (decision 2026-09-07): the label answers "what changes next, and when" directly. With no markets selected, keep a clock glyph so Settings stays reachable.

### Settings

Native Settings scene, four tabs sized per tab. Rows follow the kit form pattern: 13pt Medium title, 11pt Medium secondary subtitle, trailing control or detail label; explanatory text lives in subtitles and section footers, not loose rows. General: Time Zone pop-up (North American zones plus UTC, stored as IANA identifiers, System by default, live zone name and offset in the subtitle), Holiday Coverage detail row, then Launch at Login and Quit. Markets: one toggle per session. Events: U.S. Releases and Central Banks groups, each row's subtitle showing its next bundled date, footer stating the coverage per group. Selections apply immediately and persist in `MarketPreferences`. Turning off every market is allowed; turning off every event kind hides the section. Notifications: Lead Time pop-up (At the time, 5, 15, 30 minutes before), then Markets and the two event groups as toggles, all off by default and independent of what the popover shows; the form scrolls at the Events tab height. A market notifies at the first open and final close of its trading day in the canonical zone (lunch recesses and CME's daily maintenance gap stay silent, holidays and early closes already applied); an event notifies at its scheduled start, BOJ with the approximation marker. Notifications are local `UNUserNotificationCenter` requests planned deterministically from the bundled schedule, authorization is requested on the first toggle, and a denied state shows one row linking to System Settings › Notifications. Body text uses the display zone.

### Non-features

No network entitlement or code, no dependencies, no telemetry, no accounts. If live fetching is ever added it is a separate phase: sandboxed XPC helper, `federalreserve.gov` only, weekly, off by default. Excluded event kinds: jobless claims, ISM, JOLTS, consumer confidence, options expiries.

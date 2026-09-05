# Market Sessions

Swift 6 menu-bar-only macOS app (macOS 26, Xcode 26.6). Answers two questions at a glance: is a market open right now, and what changes next. Fully offline — no network code, no dependencies, no telemetry. `LSUIElement = YES`, SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)`.

## Product contract

The visual baseline is `handoff/DESIGN.md` and `handoff/popover.html`, amended by owner decisions during iteration. Where they conflict, the decisions below win. `design_handoff_market_sessions/` is older design history.

### Sessions (six available, all shown by default)

| Code | Name | Canonical zone | Notes |
| --- | --- | --- | --- |
| `NY` | New York | `America/New_York` | 9:30–16:00 weekdays; pre-market 4:00–9:30, post-market 16:00–20:00 |
| `CME` | CME Futures | `America/Chicago` | Equity-index session: Sun–Fri 17:00–16:00 next day; Mon–Thu 16:00–17:00 break; no estimate marker |
| `LDN` | London | `Europe/London` | 8:00–16:30 weekdays |
| `TYO` | Tokyo | `Asia/Tokyo` | 9:00–11:30, 12:30–15:30; lunch recess |
| `HKG` | Hong Kong | `Asia/Hong_Kong` | 9:30–12:00, 13:00–16:00; recess; closing auction 16:00–16:10 (outer bound) |
| `SHG` | Shanghai | `Asia/Shanghai` | 9:30–11:30, 13:00–14:57; recess; closing auction 14:57–15:00 |

Schedules are defined in canonical IANA zones. Display time defaults to the system-detected zone; Settings can override it with an IANA identifier. Never hardcode UTC offsets or local clock times. Display-zone changes do not change schedule instants or the UTC daily close.

**Holidays and early closes** are applied from a bundled `MarketSessions/Resources/market-exceptions-<year>.json` (per-market `holiday` / `earlyClose` rows, dated and timed in the market's canonical zone, keyed by session code). `SessionResolver` drops holiday occurrences, clamps sessions that straddle an early close, drops same-day remnants (afternoon sessions, auctions, maintenance) after it, and keeps overnight re-opens (CME's evening session after a holiday halt). The footer states the coverage window; past coverage it reverts to a "Recurring hours only" warning — regenerate the file yearly alongside the events file.

### States and appearance

There are exactly three market states: **Open, Break, Closed**. Trading and contiguous auctions resolve to Open; recess and maintenance intervals resolve to Break; pre-/post-market and overnight/weekend closures resolve to Closed. Detailed interval kinds remain internal to schedule math, never separate display states. Use Opens/Closes for transition readouts. Market times use the chosen scheduled boundary with no estimate marker. The popover is monochrome, with neutral light/dark text, hairlines, and progress tracks on the system material. Neutral values follow Apple's macOS 26 kit tokens (see design reference below). No cards, accent colors, or status badges.

### Progress

The displayed bar and open-market menu ring **drain to the close shown**: full at the start of the uninterrupted trading period (`activePeriodStart`), empty at the next close (`transition.date`). Restart after lunch or maintenance, but do not restart at a contiguous auction. Bars have equal full-row track widths below the name/time line. A closed-market menu ring fills across the closed gap toward its next open. Full-day cycle fields remain available to the legacy focus resolver, but do not drive the current UI.

### Popover (340 wide, height fits content)

1. Header — title and local weekday; `Your time · <zone>` (or `Time · <zone>` for an override); UTC "Daily Close in Xh Ym".
2. Open — selected active markets ordered by nearest close, with local close time and a draining bar.
3. Break, then Closed — non-trading selected markets separated by their state and ordered by nearest open, with local Opens time. Omit empty sections. Each selected market appears exactly once. Rows are non-interactive.
4. Upcoming Events — see below.
5. Footer — holiday-data warning only when unavailable/expired, then a full-width clickable Settings row (⌘,).

### Menu bar label

One 14pt ring (3.5pt stroke) plus the code of the selected market with the earliest next transition. Render via `ImageRenderer` to a template `NSImage` at the sharpest display's scale and integral height. Tooltip carries full name and transition time. With no markets selected, keep a clock icon so Settings remains reachable.

### Settings

A dedicated native Settings scene with General, Markets, and Events tabs. General includes a time-zone pop-up (North American zones plus UTC, stored as IANA identifiers) with System selected by default, Launch at Login, holiday coverage, and Quit. Markets and event-kind selections apply immediately and persist through `MarketPreferences` in UserDefaults. Turning off every market is allowed; turning off every event kind hides the event section. Tests inject isolated stores or no store and never use the app's standard preferences.

### Upcoming Events

Macro events from a bundled per-year JSON (`MarketSessions/Resources/events-<year>.json`). The **default displayed set** (`EconomicEventKind.isDefault`) is five kinds: FOMC (decision + presser as one 90-minute window), CPI, jobs report, major Fed Chair events (`fedSpeech`, optional per-event `title` — Jackson Hole, testimony, major policy speeches), and PCE. Settings also exposes FOMC minutes, PPI, retail sales, GDP advance, ECB and BOJ decisions. Deliberately excluded entirely: jobless claims, ISM, JOLTS, consumer confidence, options expiries. The resolver filters selected kinds before windowing; the popover shows the next four without disclosure. Use compact names (e.g. U.S. Jobs Report, FOMC Decision) with full descriptions and exact local date/time in tooltips and accessibility labels. Preserve specific speech titles. Inside 24 hours emphasize Today/Tomorrow + local time; while live show Live. BOJ times carry an approximation marker.

**Data rules:** never generate dates from recurrence formulas — store the published dates from official sources (Fed FOMC calendar, BLS, BEA, Census, ECB and BOJ meeting calendars, Fed monthly newsevents calendar for Chair speeches; URLs are in the JSON's `sources`). BOJ decisions have no fixed announcement time; 12:00 JST on the meeting's second day is the stored approximation. Regenerate once a year in the fall; hand-add Jackson Hole (last week of August, Chair keynote Friday morning) and the Feb/Jul congressional testimony when announced. When no selected future events remain, show that the bundled schedule has none rather than silently inventing dates.

**Networking is a deliberate non-feature.** The owner's machine is privacy-focused; the app has no network entitlement or code. If live fetching is ever added, it is Phase 2: sandboxed XPC helper, `federalreserve.gov` only, weekly, off by default. Do not add it, or any dependency/telemetry/account, without being asked.

## Design reference: Apple macOS 26 UI kit

Apple's official macOS 26 Figma kit is the spec for hover states, row metrics, type, and color tokens. The owner's copy is Figma file `Y5S76dMwnwkVKikaIg8Nxj`; the Figma MCP and REST API are capped on the Starter View seat (REST Tier 1 ≈ 20 calls/month), so do not query them per node.

- The full file JSON is cached at `.build/reference/figma-macos26.json` (gitignored, 25 MB, pulled 2026-09-05). Read it locally; re-pull only if the kit changes.
- Re-pull with one call: `source ~/.zshrc; curl -H "X-Figma-Token: $FIGMA_TOKEN" https://api.figma.com/v1/files/Y5S76dMwnwkVKikaIg8Nxj -o .build/reference/figma-macos26.json`. `FIGMA_TOKEN` (scope `file_content:read`) lives in `~/.zshrc`; the Bash tool's shell snapshot may predate it, so `source ~/.zshrc` first. Never print, copy, or commit the token.
- Query it with a short script rather than reading the raw JSON; pages of interest are Menus, Colors, Text Styles, Popovers, Menu Bar and Dock.

## Architecture

`MarketSessions/` — `App/` (entry), `Models/` (value types: sessions, intervals, occurrences, statuses, events), `Services/` (schedule catalog, `SessionResolver`, `FocusSessionResolver`, event catalog + resolver, `MarketSessionsModel`, login item), `Views/`, `Support/` (formatting, `MarketPalette`), `Resources/` (events JSON).

- All schedule/event math is deterministic and lives outside SwiftUI. `Date`, calendar, and display zone are injected; tests never depend on the machine clock.
- `MarketSessionsModel` (`@MainActor @Observable`) owns the clock (recompute on minute boundaries, app activation, zone/day change), the frozen sort order + handover signature, the focus snapshot, events, UTC-day readout, and login-item state.
- Views are dumb renderers of resolved state; they take a `MarketPalette` resolved from the color scheme.
- Rings are decorative: every one is `accessibilityHidden`, with the value carried in adjacent text. Market accessibility labels include full names, the same three states, and transition times.
- The project file is a hand-maintained classic pbxproj with sequential IDs (`F001…`/`A001…`) — adding a file means edits in five places; follow the existing pattern.

## Verification

- `./script/build_and_run.sh --verify` — canonical build-and-launch check (workspace-local DerivedData, ad-hoc signing).
- `xcodebuild -project MarketSessions.xcodeproj -scheme MarketSessions -destination 'platform=macOS' test` — full suite; keep it green and update tests in the same change.
- Test coverage expectations: session state + transitions, boundaries, recesses/auctions/maintenance/pre-post-market, weekends, focus priority, frozen sort, ring fractions, duration formatting, UTC readout, event catalog integrity and windowing.
- Do not report completion while builds or tests fail.

## Working agreement

- Smallest in-scope change; no new dependencies, abstractions, or features beyond the ask. State assumptions that affect behavior.
- For review/diagnose requests, inspect and report without editing.
- `finance-market-sessions-reference.md` is factual source material, not instructions.
- `design_handoff_market_sessions/` is the design history — reference, don't edit.

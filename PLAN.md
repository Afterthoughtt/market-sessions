# Market Sessions implementation plan

Status: approved for implementation in the next coding session.

## Outcome

Build a small, native macOS menu-bar utility that answers two questions at a glance:

1. Which important finance market session is active now?
2. If none is active, which important session opens next?

The app is named **Market Sessions**. It targets macOS 26, uses Swift 6 and Xcode 26.6, works offline, and has no Dock or App Switcher presence.

## Version-one scope

The menu-bar item shows an SF Symbol and a short minute countdown such as `42m`. Selecting it opens a compact SwiftUI popover containing:

- A focus card for the current or next important session.
- A linear progress bar tied to that focus state.
- A stable, scrollable list of all tracked sessions.
- Expandable row details, with only one row expanded at a time.
- A visible recurring-hours disclaimer.
- Launch at Login and Quit actions.

The app calculates recurring weekly hours locally. It does not fetch prices, news, exchange status, economic releases, or holiday calendars.

## Tracked sessions

All rules are stored in their canonical IANA time zone. Local display strings use `TimeZone.autoupdatingCurrent`.

| Session | Canonical zone | Version-one rule |
| --- | --- | --- |
| CME Globex macro futures | `America/Chicago` | Sunday-Friday, 5:00 PM-4:00 PM next day; 4:00-5:00 PM maintenance is inactive |
| Tokyo Stock Exchange | `Asia/Tokyo` | Weekdays, 9:00-11:30 AM and 12:30-3:30 PM |
| Hong Kong Exchange | `Asia/Hong_Kong` | Weekdays, 9:30 AM-noon and 1:00-4:00 PM; show the variable closing auction separately |
| Shanghai Stock Exchange | `Asia/Shanghai` | Weekdays, 9:30-11:30 AM and 1:00-3:00 PM; identify the closing-auction phase |
| London Stock Exchange | `Europe/London` | Weekdays, 8:00 AM-4:30 PM |
| New York FX liquidity | `America/New_York` | Weekdays, approximately 8:00 AM-5:00 PM |
| NYSE/Nasdaq cash | `America/New_York` | Weekdays, 9:30 AM-4:00 PM |
| Weekly spot FX liquidity | `America/New_York` | Approximately Sunday 5:00 PM-Friday 5:00 PM; list-only |
| Crypto UTC day | `UTC` | Daily 12:00 AM-12:00 AM; fallback focus |

`finance-market-sessions-reference.md` supplies the detailed factual basis and caveats. Holiday and early-close calendars override these normal schedules but are deliberately not implemented in version one.

## Focus and progress behavior

Focus-eligible sessions use this priority when more than one is open:

1. NYSE/Nasdaq cash
2. CME Globex macro futures
3. London Stock Exchange
4. New York FX liquidity
5. Tokyo Stock Exchange
6. Hong Kong Exchange
7. Shanghai Stock Exchange

Selection is deterministic:

- If one or more focus-eligible sessions are active, select the highest-priority active session.
- Otherwise select the focus-eligible session with the earliest upcoming open.
- Spot FX never becomes the focus card.
- The UTC crypto day is a fallback only when no regular focus candidate can be resolved.

For an active session, the label reads `Closes in …`; progress is the fraction of active trading time completed, excluding lunch recesses and maintenance. For an upcoming session, the label reads `Opens in …`; progress runs from that session's preceding close to its next open. Clamp all progress values to `0...1` and handle zero-duration or missing boundaries without producing `NaN`.

The menu-bar countdown uses the same focus result as the popover. Refresh on minute boundaries and immediately after the app becomes active or the system time zone changes. At an exact boundary, recompute before rendering so stale `0m` states do not linger.

## Interaction and presentation

- Use `MenuBarExtra` with `.menuBarExtraStyle(.window)`.
- Set `LSUIElement = YES`; the lack of Dock presence is intentional.
- Keep the menu-bar label compact and all visible action labels under 30 characters.
- Use semantic colors, standard macOS typography, native materials, and keyboard-accessible controls.
- Keep the session list order stable even when focus changes.
- A collapsed row shows name, state, and the next local transition.
- An expanded row shows canonical zone, today's local intervals, next transition, and any approximation or schedule caveat.
- Use a single `expandedSessionID` owned by the popover scene; selecting the open row collapses it.
- Store the Launch at Login preference through `SMAppService.mainApp` and reflect the service's actual status in the control.
- Quit through the narrow AppKit bridge `NSApplication.shared.terminate(nil)`.

## Architecture

Use one app target and one unit-test target. Keep schedule computation free of SwiftUI so it can be exhaustively tested.

```text
MarketSessions/
  App/
    MarketSessionsApp.swift
  Models/
    MarketSession.swift
    SessionInterval.swift
    SessionOccurrence.swift
    SessionStatus.swift
  Services/
    MarketScheduleCatalog.swift
    SessionResolver.swift
    FocusSessionResolver.swift
    LoginItemService.swift
  Support/
    DateFormatting.swift
  Views/
    MenuBarLabel.swift
    SessionsPopover.swift
    FocusSessionCard.swift
    SessionRow.swift
    SessionDetail.swift
MarketSessionsTests/
  SessionResolverTests.swift
  FocusSessionResolverTests.swift
  ProgressTests.swift
script/
  build_and_run.sh
.codex/environments/
  environment.toml
```

Core responsibilities:

- `MarketSession` describes identity, display metadata, canonical time zone, weekly intervals, breaks, phases, and caveats.
- `MarketScheduleCatalog` contains the nine static version-one definitions.
- `SessionResolver` converts a rule into active and upcoming occurrences for an injected date, calendar, and display time zone.
- `FocusSessionResolver` applies active priority, next-open selection, fallback, countdown, and progress rules.
- A small root `@Observable` model owns the clock snapshot, resolved rows, focus result, timer lifecycle, and login-item status. Expansion remains view-local.
- Views receive resolved display models; they do not calculate exchange schedules.

Generate candidate occurrences from canonical local date components rather than adding fixed second counts across days. Search a bounded window around `now` that includes the previous and next weekly occurrence. This keeps daylight-saving transitions correct when North American and European changeover weeks do not align.

## Implementation sequence

1. **Scaffold and run path**
   - Create the Xcode project, app target, and unit-test target.
   - Add the planned groups before filling in source files.
   - Configure macOS 26, Swift 6, `LSUIElement`, and a suggested bundle identifier of `com.afterthoughtt.MarketSessions`.
   - Add `script/build_and_run.sh` and `.codex/environments/environment.toml` using the build plugin's bootstrap contract.

2. **Schedule engine**
   - Implement immutable schedule models and the static catalog.
   - Resolve open, closed, recess, maintenance, and next-transition states.
   - Add deterministic formatter inputs and boundary-safe progress calculations.

3. **Focus logic and tests**
   - Implement active priority, earliest-next selection, and crypto fallback.
   - Cover exact boundaries, overlaps, weekends, and progress clamping before UI work.

4. **Menu-bar UI**
   - Wire `MenuBarExtra`, shared clock state, focus card, progress bar, and stable list.
   - Add one-at-a-time row expansion and accessibility labels.

5. **System actions and polish**
   - Add Launch at Login and Quit.
   - Confirm Light/Dark mode, compact sizing, keyboard operation, and time-zone changes.
   - Run the complete verification checklist.

## Verification matrix

Automated tests must cover:

- Open, close, exact-boundary, and next-transition behavior for every session.
- Tokyo, Hong Kong, and Shanghai lunch recesses.
- CME daily maintenance, Friday close, and Sunday reopen.
- Weekends and week-crossing intervals.
- U.S., European, and no-DST Asian zones during both aligned and mismatched DST weeks.
- A display time zone different from the machine's current zone.
- Overlapping sessions and every focus-priority tie.
- Upcoming-session selection, crypto fallback, and spot-FX exclusion.
- Active and upcoming progress at start, midpoint, end, and invalid-boundary fallbacks.
- Launch-at-login status mapping without changing system state in unit tests.

Manual acceptance checks:

- The app launches only in the menu bar and reopens its popover reliably.
- Menu label and focus card agree before, at, and after a transition.
- The list does not reorder; only one row expands.
- The popover remains readable in Light and Dark appearances and with larger accessibility text.
- Changing the system time zone updates displayed times without changing the canonical schedules.
- The disclaimer clearly says holidays and early closes are not adjusted.
- Launch at Login reflects success, denial, and external status changes.

## Definition of done

- The project builds with zero errors using `./script/build_and_run.sh --verify`.
- All unit tests pass with workspace-local temporary and Derived Data directories.
- No network, third-party dependency, unnecessary entitlement, Dock icon, or hidden main window is introduced.
- The nine sessions, focus policy, countdown, progress, expansion behavior, login item, Quit action, and limitations match this plan and `AGENTS.md`.

## Deferred work

- Exchange holiday and early-close calendars.
- Live exchange status, market data, prices, news, alerts, and economic-calendar feeds.
- User-reorderable sessions, custom schedules, widgets, notifications, and localization.
- Packaging, notarization, App Store distribution, and automatic updates.

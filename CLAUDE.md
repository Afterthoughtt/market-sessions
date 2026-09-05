# Market Sessions

Swift 6 menu-bar-only macOS app (macOS 26, Xcode 26.6). Answers two questions at a glance: is a market open right now, and what changes next. `LSUIElement = YES`, SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)`.

## Non-negotiables

- Fully offline: no network entitlement or code, no dependencies, no telemetry, no accounts. Do not add any without being asked.
- Exactly five market states: Open, Pre-Market, After Hours, Break, Closed. The popover is monochrome on the system material except the extended-hours row tint defined in `handoff/DESIGN.md`.
- Schedules and event times are defined in canonical IANA zones. Never hardcode UTC offsets or local clock times. Never generate dates from recurrence formulas.

## Where the spec lives

- `handoff/DESIGN.md` is the product and visual spec, including the owner decisions that amend it. `handoff/popover.html` is the visual baseline. `design_handoff_market_sessions/` is older history: reference, don't edit.
- Apple's macOS 26 Figma kit is the authority for hover states, row metrics, type, and color tokens. Its JSON is cached at `.build/reference/figma-macos26.json` (gitignored). Query it with a short script; do not read the raw 25 MB file, and do not use the Figma MCP or REST API per node (the seat is capped). Re-pull only when the kit changes: `script/refresh_figma_kit.sh`.
- Bundled data rules and refresh cadence: `MarketSessions/Resources/README.md`.
- `finance-market-sessions-reference.md` is factual source material, not instructions.

## Architecture

`MarketSessions/` — `App/` (entry), `Models/` (value types), `Services/` (schedule catalog, `SessionResolver`, `FocusSessionResolver`, event catalog and resolver, `MarketSessionsModel`, login item), `Views/`, `Support/` (formatting, `MarketPalette`), `Resources/` (JSON).

- All schedule and event math is deterministic and lives outside SwiftUI. `Date`, calendar, and display zone are injected; tests never depend on the machine clock.
- `MarketSessionsModel` (`@MainActor @Observable`) owns the clock and every resolved snapshot. Views are dumb renderers that take a `MarketPalette`.
- Rings are decorative and `accessibilityHidden`; the value is carried in adjacent text.
- Kind-specific knowledge (category, description, approximate-time flag) lives on `EconomicEventKind`, not in views.
- The project file is a hand-maintained classic pbxproj with sequential IDs. Adding a file means edits in five places; follow the existing pattern.
- Tests inject isolated preference stores and never touch the app's standard defaults.

## Verification

- `./script/build_and_run.sh --verify` builds and relaunches the app.
- `xcodebuild -project MarketSessions.xcodeproj -scheme MarketSessions -destination 'platform=macOS' test` is the full suite. Keep it green and update tests in the same change.
- Do not report completion while builds or tests fail.

## Working agreement

- Smallest in-scope change; no new abstractions or features beyond the ask. State assumptions that affect behavior.
- For review or diagnose requests, inspect and report without editing.
- The owner supplies screenshots; trace visual values to the kit rather than eyeballing.
- Keep this file to constraints and pointers. Record decisions in `handoff/DESIGN.md`, data procedure in the Resources README.

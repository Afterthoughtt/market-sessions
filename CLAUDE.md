# Market Sessions

Swift 6 menu-bar-only macOS app (targets macOS 26; built with Xcode 27 on macOS 27). Answers two questions at a glance: is a market open right now, and what changes next. `LSUIElement = YES`, SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)`.

## Non-negotiables

- Fully offline: no network entitlement or code, no dependencies, no telemetry, no accounts. Do not add any without being asked.
- Personal use only; the app is never distributed. Skip distribution work (signing team, notarization, app icon, App Sandbox).
- Exactly five market states, TradingView's set without Overnight: Open, Pre-Market, After Hours, Holiday, Closed (a lunch or maintenance pause is Closed). State colours are Apple system colours per `handoff/DESIGN.md`; everything else in the popover stays neutral on the system material.
- Schedules and event times are defined in canonical IANA zones. Never hardcode UTC offsets or local clock times. Never generate dates from recurrence formulas.

## Where the spec lives

- `handoff/DESIGN.md` is the product and visual spec, including the owner decisions that amend it; check it before every UI change. `handoff/popover.html` is the visual baseline. `design_handoff_market_sessions/` is older history: reference, don't edit.
- Apple's macOS 27 Figma kit (the owner's copy of the Community file) is the authority for hover states, row metrics, type, color tokens and progress indicators, alongside the HIG and the macOS Development plugin. Its JSON is cached at `.build/reference/figma-macos27.json` (gitignored). Query it with a short script; do not read the raw 44 MB file, and do not use the Figma MCP or REST API per node (the seat is capped). Re-pull only when the kit changes: `script/refresh_figma_kit.sh`.
- Design canvas (claude.ai Design artifact): https://claude.ai/artifact/M5fVqd3m8KeL5dtamtVKKm. Kit tokens, popover anatomy, findings, menu bar and Settings boards; update the matching board when UI ships.
- Custom SF Symbols: the San Francisco font is licensed for mock-ups only, so never bake SF Pro glyph outlines into assets. Letters come from SF Symbols template exports in `symbols export/` (gitignored).
- Bundled data rules and refresh cadence: `MarketSessions/Resources/README.md`.
- Known issues and the open work list: `handoff/OPEN_ISSUES.md`. Start there when resuming.
- `finance-market-sessions-reference.md` is factual source material, not instructions.

## macOS Development skills (always)

- Load `macos-development:standards` at the start of every session, before any design, code, build, or review work. Its rules, and its references `compatibility.md` (SDK and API availability) and `fetching-apple-sources.md` (reading Apple docs and HIG pages), apply throughout.
- Then use the task's skill: `design` for new UI or interaction planning, `native-ui` when writing or changing SwiftUI/AppKit code, `build-debug` for builds, tests, crashes and performance, `design-review` and `accessibility-audit` before calling a change to layout, interaction, or states done. `release-check` is out of scope (never distributed).
- This file and the spec sources above (DESIGN.md owner decisions, the Figma kit) override the skills' defaults where they differ.

## Architecture

`MarketSessions/` — `App/` (entry), `Models/` (value types), `Services/` (schedule catalog, `SessionResolver`, countdown helpers, event catalog and resolver, notifications, `MarketSessionsModel`, login item), `Views/`, `Support/` (formatting, `MarketPalette`), `Resources/` (JSON).

- All schedule and event math is deterministic and lives outside SwiftUI. `Date`, calendar, and display zone are injected; tests never depend on the machine clock.
- `MarketSessionsModel` (`@MainActor @Observable`) owns the clock and every resolved snapshot. Views are dumb renderers that take a `MarketPalette`.
- Battery: the clock ticks per minute only while the popover or Settings is live (`setLiveSurface`); otherwise it sleeps until the next transition, the pill trace's next step (1/60 of the open run), or an hour. Put periodic work in `refresh()`.
- The menu bar pill is a cached template image (`ImageRenderer`); SwiftUI shapes do not draw in a `MenuBarExtra` label.
- Kind-specific knowledge (category, description) lives on `EconomicEventKind`, not in views.
- The project file is a hand-maintained classic pbxproj with sequential IDs. Adding a file means edits in five places; follow the existing pattern.
- Tests inject isolated preference stores and never touch the app's standard defaults.

## Verification

- `./script/build_and_run.sh --verify` builds and relaunches the app. It signs ad hoc (`CODE_SIGN_IDENTITY=-`); a build with `CODE_SIGNING_ALLOWED=NO` is refused by the notification daemon and never appears in System Settings › Notifications.
- `xcodebuild -project MarketSessions.xcodeproj -scheme MarketSessions -destination 'platform=macOS' -derivedDataPath .build/DerivedData test` is the full suite. Keep the `-derivedDataPath`: Xcode previews share the default DerivedData and leave an unsigned test bundle that fails CodeSign. Keep it green and update tests in the same change.
- Do not report completion while builds or tests fail.
- The `xcode` MCP server is available for Apple docs and previews; the commands above stay the source of truth. `Views/Previews.swift` (DEBUG only, fixed Tue 2026-09-29 5:30 PM ET) renders the popover, each Settings tab and the menu bar label through `RenderPreview`; the preview host draws its own window chrome and no menu bar, so those still need owner screenshots.

## Working agreement

- Smallest in-scope change; no new abstractions or features beyond the ask. State assumptions that affect behavior.
- For review or diagnose requests, inspect and report without editing.
- The owner supplies screenshots; trace visual values to the kit rather than eyeballing.
- Keep this file to constraints and pointers. Record decisions in `handoff/DESIGN.md`, data procedure in the Resources README.

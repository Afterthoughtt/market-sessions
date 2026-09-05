# Bundled data

Two per-year JSON sets, both loaded by filename prefix. Never generate dates from recurrence formulas; store the published dates and list the source URLs in each file's `sources`.

## `events-<year>.json`

Macro events keyed by `EconomicEventKind`. Times are in the publisher's zone.

- FOMC: decision plus press conference as one 90-minute window at 14:00 ET. Minutes: 14:00 ET, 30 minutes.
- U.S. releases (CPI, jobs, PPI from BLS; PCE, GDP advance from BEA; retail sales from Census): 08:30 ET.
- ECB: 14:15 Berlin, 90 minutes. BOJ: no fixed announcement time; store 12:00 JST on the meeting's second day and the app marks it approximate.
- Fed Chair (`fedSpeech`, per-event `title`): Jackson Hole keynote (last week of August, Friday morning) and the Feb/Jul congressional testimony, hand-added when announced. Other Chair speeches are announced only weeks ahead, so the kind is often empty.

Cadence: central banks publish 12–28 months ahead, so their next-year decisions go in a separate `events-<year>.json` as soon as verified. BLS, BEA, and Census post the following year in late fall; regenerate in December. Verify from the raw pages (curl and grep), not from summaries.

## `market-exceptions-<year>.json`

Per-market `holiday` and `earlyClose` rows, dated and timed in the market's canonical zone, keyed by session code, with a `coverageEnd`. Past coverage the app shows "Recurring hours only". Cover whole years only: HKEX and SSE publish next-year calendars in late fall (NYSE and JPX earlier), so regenerate each December together with the U.S. events, and do not bundle partial years.

## Registering a new file

The project file is a hand-maintained pbxproj with sequential IDs. A new resource needs two `PBXBuildFile` entries, one `PBXFileReference`, one group entry, and one entry in each of the two Resources build phases. Then update the catalog count tests in `MarketSessionsTests/EconomicEventTests.swift`.

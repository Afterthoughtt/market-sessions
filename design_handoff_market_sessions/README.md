# Handoff: Market Sessions — popover and menu-bar label (Turn 7)

## Overview

Market Sessions is a macOS menu-bar-only utility that answers two questions at a glance: **is a market open right now**, and **what changes next**. This handoff covers a redesign of both surfaces — the status-item label and the 390×590 popover — arrived at over seven rounds of review.

The design is in `Market Sessions.dc.html`. **Turn 7 is the current design** and the only one to implement. Turns 1–6 are earlier iterations kept as history; ignore them.

Three states are drawn:

| Id | State |
| --- | --- |
| `7a` | Weekday, Light — Friday 7:12 AM PT, three sessions open |
| `7b` | Weekday, Dark — same moment |
| `7c` | Weekend, Light — Saturday 11:40 AM PT, nothing trading |

Plus a **row-states** reference block showing all five row states at production row height.

## About the Design Files

The files in this bundle are **design references created in HTML** — prototypes showing intended look and behavior, not production code to copy. The existing app is **SwiftUI (Swift 6, macOS 26)**, so the task is to **recreate these designs in SwiftUI** using stock AppKit/SwiftUI controls and the app's existing architecture, not to port HTML.

Every measurement below is in points, matching the HTML's px 1:1 at the popover's 390×590 size.

## Fidelity

**High-fidelity.** Colors, typography, spacing, and states are final. Recreate pixel-accurately using native controls. The one deliberate exception: the light-theme status colors are custom accessible variants (see Design Tokens) rather than `Color.green` / `.orange` / `.purple`, because the system colors fail contrast on the popover background.

## What changed from the current implementation

This design **conflicts with the existing `AGENTS.md` / `PLAN.md` contract** in several places. These are intentional decisions made by the product owner during review. Where they disagree, this document wins — and `AGENTS.md`/`PLAN.md` should be updated to match.

| Area | Old contract | This design |
| --- | --- | --- |
| Session count | Nine | **Six.** New York FX and Weekly Spot FX removed entirely. |
| Crypto UTC day | A session in the list | **Not a session.** It never opens or closes, it only rolls, so it moved to the header as an ambient "Daily Close in …" readout. |
| Focus card | Separate card above a separate open-sessions summary | **Merged.** One "Open now" block whose first cell is emphasized. |
| Row expansion | Rows expand in place, one at a time, `expandedSessionID` owned by the popover | **Removed entirely.** No expansion, no disclosure triangles, no `expandedSessionID`. |
| Session detail | Expanded row showed canonical zone, intervals, caveats | **Removed.** `SessionDetail.swift` is no longer used. |
| List order | Stable, never reorders | **Re-sorts by next transition, but only at open/close handovers** — never continuously. Between handovers the order is frozen. |
| Menu-bar label | SF Symbol + countdown text (`42m`) | **Ticker code + progress ring.** No numeric countdown. |
| Bottom controls | Stacked block with disclaimer, toggle, detail text, Quit | **One 35.5pt row.** |

## Screens / Views

### 1. Menu-bar label (status item)

**Purpose:** answer "is anything open, and how far through is it" without opening anything.

Two variants:

**Open (something is trading)** — a rounded container, corner radius 5, padding 2 vertical / 7 horizontal, background `rgba(255,255,255,0.32)`, laid out horizontally with 5pt gaps:
1. Progress ring, 14×14 — the **open** market, draining toward its close
2. That market's code, 12pt, weight 500, full opacity
3. Separator `›`, opacity 0.55, 1pt horizontal padding
4. Progress ring, 14×14, opacity 0.8 — the **next** session, filling toward its open
5. That session's code, 12pt, opacity 0.8

**Closed (nothing trading)** — the same container at **opacity 0.62**, containing only the next session's ring (filling) and code.

> The dimming is load-bearing. A filling ring and a draining ring are the same shape at 14pt; the opacity, not the arc direction, is what tells the user nothing is trading.

**Ring geometry (all rings in the design):** SVG `viewBox="0 0 26 26"`, `cx=13 cy=13 r=10`, stroke width 3.5, rendered at 14×14, rotated −90° so the arc starts at 12 o'clock. Track stroke `rgba(255,255,255,0.34)`, arc stroke `#fff` (or `rgba(255,255,255,0.95)` for the secondary), round line caps.

**Arc math.** Circumference C = 2πr. Draw the arc as a dash array of `[fraction × C, C − fraction × C]`.
- **Open session:** `fraction = timeRemaining / sessionDuration` — the ring *drains* to zero at the close.
- **Closed session:** `fraction = timeElapsed / gapDuration` — the ring *fills* to full at the open.

In SwiftUI this is `Circle().trim(from: 0, to: fraction).stroke(style: StrokeStyle(lineWidth: 3.5, lineCap: .round)).rotationEffect(.degrees(-90))`.

### 2. Popover

390 wide × 590 tall, fixed. Five vertical regions, top to bottom. In the weekday state they measure 212 / 1 / 24.5 / 316 / 1 / 35.5 = **590 exactly**; the list region is the only flexible one.

---

#### Region A — Header (`padding: 14 14 10 14`, vertical stack, gap 9)

**A1. Title row** — horizontal, `alignItems: flex-start`, gap 8:
- `Market Sessions` — 15pt, weight 600, letter-spacing −0.01em, `text` color
- flexible spacer
- Right column, right-aligned, gap 3:
  - `Your time · PDT` — 10pt, `sec` color. **The zone abbreviation is the system zone**, from `TimeZone.autoupdatingCurrent`; PDT is only what the mock shows. Do not hardcode.
  - Daily Close row — horizontal, gap 5:
    - Ring, 13×13, `viewBox="0 0 16 16"`, `cx=8 cy=8 r=6`, stroke width 2, track `ringTrack`, arc `ringSec`. Fraction = fraction of the UTC day remaining (drains).
    - `Daily Close in ` 10pt `sec` + duration 10pt weight 500 `text` color, tabular figures.

**A2. Section label** — horizontal, baseline-aligned, gap 6:
- Weekday: `Open now` 10pt/600 `sec` + count (`3`) 10pt `faint`
- Weekend: `Next open` 10pt/600 `sec` + `nothing trading` 10pt `faint`

**A3. Open-now grid** — 2 equal columns, gap 7.

*Emphasized cell* (spans both columns; on the weekend it is the only cell and does not span):
- padding 12, corner radius 10, background `cell`, inset border 1pt `accentRing`
- horizontal, gap 12, vertically centered:
  - **Ring, 52×52** — `viewBox="0 0 52 52"`, `cx=26 cy=26 r=23`, stroke width 4, track `track`, arc `accent`. Session code centered inside, 13pt weight 600, letter-spacing −0.01em (12pt for 4-character codes).
  - Text column, gap 4: name 14pt/600; subtitle 11pt `sec`, **must not wrap** — `Open` in `green` weight 600, then ` · closes Today 1:00 PM`. Weekend: `Closed` weight 600 (inherits `sec`), then ` · opens Sun ≈3:00 PM`.
  - flexible spacer, min 8
  - Right column, right-aligned, gap 1: `Closes in` / `Opens in` 10pt `sec`; duration **19pt weight 600, tabular, line-height 1.15**

*Secondary cells* (one per additional open session):
- padding 9 vertical / 10 horizontal, corner radius 8, background `cell`
- horizontal, gap 9: ring 24×24 (`viewBox="0 0 24 24"`, `cx=12 cy=12 r=10`, stroke 2.5, track `track`, arc `green`); text column gap 2 — name 12pt/500 (truncate with ellipsis), `1h 18m left` 10pt `sec` tabular.

---

#### Region B — Divider

1pt, full width, `divStrong`.

---

#### Region C — List label (`padding: 8 14 4 14`, horizontal, baseline, gap 6)

- `All sessions` — 10pt/600, `sec`
- `re-sorts at each open or close` — 10pt, `faint`

---

#### Region D — Session list (flexible, `padding: 0 14 4 14`)

Six rows, **44pt each**, separated by 1pt `divider` lines inset 34pt from the left. No scroll — six rows always fit. No hover state, no click target, no expansion.

**Row** — horizontal, gap 9, `padding: 14 0`, vertically centered:

| Element | Width | Type | Color |
| --- | --- | --- | --- |
| Code | 34 | 11pt, weight 600, letter-spacing 0.02em | `sec` |
| Name | intrinsic, no wrap | 13pt, weight 500 | `text` |
| Spacer | flexible, min 6 | — | — |
| State | 72, right-aligned, **no wrap** | 11pt, weight 600 | per state, below |
| Next transition | 114, right-aligned, **no wrap**, tabular | 11pt | `sec` |

> `white-space: nowrap` on both fixed-width right-aligned columns is not optional — three separate wrap bugs during review traced to its absence. In SwiftUI: `.lineLimit(1).fixedSize(horizontal: true, vertical: false)`.

---

#### Region E — Footer (`padding: 9 14`, horizontal, gap 10, centered)

- Warning triangle glyph 11×11, 1.3 stroke, round caps + `Recurring hours only` 10pt — both `sec`
- flexible spacer
- Checkbox 13×13, corner radius 3.5 + `Launch at Login` 11pt
- `Quit` button — 11pt, padding 2 vertical / 10 horizontal, corner radius 5

Use stock `Toggle` and `Button`; the mock draws them by hand only because HTML has no AppKit.

## Row states

Five states. Six rows are shown in the reference block because both auctions share a color and it is worth seeing them adjacent.

| State | Color token | Transition column reads | Applies to |
| --- | --- | --- | --- |
| `Open` | `green` | `Closes 1:00 PM` | any session trading continuously |
| `Auction` | `purple` | `Closes 12:00 AM` | Shanghai and Hong Kong closing auctions |
| `Recess` | `orange` | `Resumes 8:30 PM` | Tokyo, Hong Kong, Shanghai lunch breaks |
| `Maintenance` | `orange` | `Reopens ≈3:00 PM` | CME daily maintenance hour |
| `Closed` | `sec` (grey) | `Opens 5:00 PM` | everything else |

**The color rule is "can you trade":**
- **Green** — continuous trading
- **Purple** — auction: orders match, but not continuously
- **Orange** — the session exists but you cannot trade: recess, or maintenance
- **Grey** — closed

Auctions previously borrowed green (Shanghai) and orange (Hong Kong) to encode a real difference that no user would ever decode. A third color states it directly.

## Sessions

Six. Rules are stored in the canonical IANA zone and rendered in `TimeZone.autoupdatingCurrent`.

| Code | Name | Canonical zone | Recurring rule |
| --- | --- | --- | --- |
| `NY` | New York Cash | `America/New_York` | Weekdays 9:30 AM – 4:00 PM |
| `CME` | CME Futures | `America/Chicago` | Sun–Fri 5:00 PM – 4:00 PM next day; 4:00–5:00 PM maintenance |
| `LDN` | London | `Europe/London` | Weekdays 8:00 AM – 4:30 PM |
| `TYO` | Tokyo | `Asia/Tokyo` | Weekdays 9:00–11:30 AM, 12:30–3:30 PM |
| `HKG` | Hong Kong | `Asia/Hong_Kong` | Weekdays 9:30 AM–12:00, 1:00–4:00 PM; variable closing auction |
| `SHG` | Shanghai | `Asia/Shanghai` | Weekdays 9:30–11:30 AM, 1:00–3:00 PM; closing auction 2:57–3:00 PM |

**Removed:** New York FX and Weekly Spot FX. Both were conventions rather than exchange sessions, and cutting them made every remaining code a city (except CME, the one venue name everybody already says out loud) — so the code vocabulary is guessable rather than memorized.

**Crypto UTC day** is no longer a session. It is the header's Daily Close readout.

### CME, specifically

CME has no tooltip to hide its caveats in, so two things are carried in the row itself:

1. Its 2:00 PM local close is a **one-hour maintenance break, not a real close** — so the transition column reads **`Breaks ≈2:00 PM`**, not `Closes`. Shorter and truer, and it sets up the `Maintenance` state that follows an hour later.
2. The **`≈`** prefix marks CME's approximate settlement timing. It appears only on CME rows: `Breaks ≈2:00 PM`, `Reopens ≈3:00 PM`, `Opens Sun ≈3:00 PM`.

Hong Kong's variable auction end is **not** surfaced. It was dropped deliberately.

## Interactions & Behavior

The popover is almost entirely non-interactive by design — it is a readout.

- **No row interaction.** No hover, no click, no expansion, no selection. Rows are static text.
- **No tooltips.** Removed entirely; a menu-bar popover closes on click-away and hover requires dwelling.
- **Launch at Login** — stock `Toggle`, bound to `SMAppService.mainApp` status.
- **Quit** — `NSApplication.shared.terminate(nil)`, ⌘Q.

### Refresh and sort timing

- Recompute on minute boundaries, on app activation, and on `NSSystemTimeZoneDidChange`. At an exact boundary, recompute before rendering so a stale `0m` never shows.
- **The list re-sorts only at handovers.** Sort key is time-to-next-transition ascending, but the sorted order is **recomputed only when some session opens or closes** — not every minute. Between handovers the order is frozen, so the list holds still for hours at a time.
  - Implementation: keep the resolved order in state; recompute it only when the set of session states changes, not on every clock tick. Countdown text updates every minute; row order does not.
- Rings animate continuously; nothing else moves.

### Weekend / empty state

When no session is trading:
- The label reads **`Next open`** with **`nothing trading`** instead of a count
- The grid collapses to **one full-width cell** — no secondary cells — showing the next session to open, its ring filling toward the open, and `Opens in {duration}`
- All six rows read `Closed`, ordered by next open
- The menu bar shows the next code and a filling ring at 0.62 opacity

## State Management

Existing architecture holds. The root `@Observable` model owns the clock snapshot, resolved sessions, focus result, timer lifecycle, and login-item status. Changes:

| Variable | Change |
| --- | --- |
| `expandedSessionID` | **Delete.** No expansion. |
| `sortedSessionIDs` | **Add.** The frozen list order, recomputed only on handover. |
| `lastHandoverStateSignature` | **Add.** Set of session states; when it changes, recompute `sortedSessionIDs`. |
| `utcDayProgress` | **Add.** Fraction of the UTC day remaining, for the header. |
| `focus` | Now drives both the emphasized cell and the menu-bar label; on the weekend it resolves to the next session to open. |

No data fetching. Everything is computed locally from static schedules.

## Design Tokens

### Light

| Token | Value | Used for |
| --- | --- | --- |
| `text` | `rgba(0,0,0,0.85)` | primary text |
| `sec` | `rgba(0,0,0,0.62)` | secondary text, codes, transitions, Closed |
| `faint` | `rgba(0,0,0,0.55)` | tertiary hints |
| `divider` | `rgba(0,0,0,0.08)` | row separators |
| `dividerStrong` | `rgba(0,0,0,0.1)` | region separators |
| `cell` | `rgba(255,255,255,0.72)` | open-now cell background |
| `track` | `rgba(0,0,0,0.09)` | ring tracks |
| `ringTrack` | `rgba(0,0,0,0.12)` | header ring track |
| `ringSec` | `rgba(0,0,0,0.42)` | header ring arc |
| `accent` | `#007AFF` | focus ring arc |
| `accentRing` | `rgba(0,122,255,0.28)` | focus cell inset border |
| `green` | `#1E7A34` | Open |
| `orange` | `#8A6100` | Recess, Maintenance |
| `purple` | `#8944AB` | Auction |
| `popover` | `rgba(246,246,246,0.96)` | popover background |

> The three status colors are **custom accessible variants, not the system colors.** Apple's `systemGreen` (#28CD41), `systemOrange` (#FF9500) and `systemPurple` (#AF52DE) measure 1.80:1, 1.87:1 and 3.50:1 against the light popover background — all below the 4.5:1 minimum for 11pt text. The values above clear it. A dark amber is used rather than Apple's accessible orange (#C93400), which passes but reads as an alarm color that "Recess" and "Maintenance" do not warrant.

### Dark

| Token | Value |
| --- | --- |
| `text` | `rgba(255,255,255,0.92)` |
| `sec` | `rgba(255,255,255,0.55)` |
| `faint` | `rgba(255,255,255,0.52)` |
| `divider` / `dividerStrong` | `rgba(255,255,255,0.1)` |
| `cell` | `rgba(255,255,255,0.07)` |
| `track` | `rgba(255,255,255,0.16)` |
| `ringTrack` | `rgba(255,255,255,0.18)` |
| `ringSec` | `rgba(255,255,255,0.55)` |
| `accent` | `#0A84FF` |
| `accentRing` | `rgba(10,132,255,0.55)` |
| `green` | `#32D74B` |
| `orange` | `#FF9F0A` |
| `purple` | `#BF5AF2` |
| `popover` | `rgba(30,30,32,0.97)` |

Dark-theme status colors are the standard system values and pass contrast (8.70:1, 8.06:1, 4.75:1) — do not substitute the light variants.

### Typography

System font throughout (`-apple-system` / SF Pro Text). No custom fonts.

| Role | Size | Weight | Notes |
| --- | --- | --- | --- |
| Popover title | 15 | 600 | letter-spacing −0.01em |
| Focus countdown | 19 | 600 | tabular, line-height 1.15 |
| Focus session name | 14 | 600 | |
| Focus code (in ring) | 13 | 600 | letter-spacing −0.01em |
| Row name | 13 | 500 | no wrap |
| Focus subtitle | 11 | 400 | no wrap |
| Row state | 11 | 600 | no wrap |
| Row transition | 11 | 400 | tabular, no wrap |
| Row code | 11 | 600 | letter-spacing 0.02em |
| Menu-bar code | 12 | 500 | |
| Secondary cell name | 12 | 500 | truncates |
| Section labels | 10 | 600 | |
| Hints, footer, cell countdowns | 10 | 400 | tabular where numeric |

Apply `.monospacedDigit()` to every countdown and clock time.

### Spacing & geometry

| Value | Used for |
| --- | --- |
| 4, 6, 7, 8, 9, 10, 12, 14 | the whole spacing scale |
| 590 × 390 | popover |
| 44 | list row height |
| 34 / 72 / 114 | row column widths (code / state / transition) |
| 52 / 24 / 14 / 13 | ring diameters (focus / secondary cell / menu bar / header) |
| 5, 8, 10, 12 | corner radii (button, secondary cell, focus cell, popover) |
| 1 | all dividers |

## Assets

None. Every graphic is drawn: rings are stroked circles, the footer warning is an inline path. No images, no icons, no SF Symbols in the final design — the menu-bar symbol was replaced by the ticker code and ring.

## Cases the design does not draw

The mock only ever shows **three** open sessions or **zero**. Two cases in between, and one above, are unresolved — flag them rather than guessing.

### The open-now grid does not hold every open count

The grid is 2 columns: an emphasized cell spanning both, then one secondary cell each. That is only clean at 1 and 3.

| Open | Layout | Problem |
| --- | --- | --- |
| 0 | one full-width cell (`Next open`) | fine — drawn in `7c` |
| 1 | emphasized cell only | fine |
| 2 | emphasized + 1 secondary | **one empty grid cell.** Let the single secondary span both columns, or fall back to a 1-column stack |
| 3 | emphasized + 2 secondary | fine — drawn in `7a` |
| 4 | emphasized + 3 secondary | **two secondary rows, one empty cell, and Region A grows ~48pt** — the list can then fit only five 44pt rows, so it must scroll |

**Four open is not hypothetical.** CME trades nearly 24h, so during Asian hours CME + Tokyo + Hong Kong + Shanghai are all open at once — a daily occurrence, not an edge case. Decide whether Region A scrolls, whether the secondary cells become a 1-column list past three, or whether the block caps at three with a "+1 more" affordance.

### Not handled at all

- **Holidays and half-days.** Out of scope by decision — the footer's `Recurring hours only` disclaimer exists precisely to admit this. A market closed for a holiday will show `Open`. Do not silently fix this; it is a known, accepted limitation.
- **DST transition windows.** IANA zones handle the arithmetic, but London and New York switch weeks apart, so the overlap shifts twice a year and the sort order changes with it. Nothing to build — just don't hardcode offsets. The mock's PDT times are valid for one date only.
- **Preferences window.** There isn't one. `Launch at Login` in the footer is the only setting.

## Accessibility

The redesign **removed the only text a screen reader could read** from the menu bar — the countdown became a ring, and the session name became a 2–3 letter code. Both need explicit labels; neither is inferable from what is drawn.

| Element | Label |
| --- | --- |
| Status item, open | `New York Cash, open, closes in 5 hours 48 minutes. Tokyo opens in 9 hours 48 minutes.` — the full names, not the codes, and the countdown the ring replaced |
| Status item, closed | `No markets open. CME Futures opens in 1 day 3 hours.` |
| Emphasized cell | name + state + countdown as one label; the ring is decorative, `accessibilityHidden` |
| Session row | one label per row, not four — `Tokyo, closed, opens 5:00 PM`. Read the **name**, never the code. |
| `≈` (U+2248) | must not be read as a glyph. `Reopens approximately 3:00 PM`. |
| Rings | all decorative; hide every one from the accessibility tree |

Every ring in this design is redundant with adjacent text by design — so hiding them loses nothing, provided the text labels above exist.

## Screenshots

In `screenshots/`, captured at 2× from the design file:

| File | What it shows |
| --- | --- |
| `7a-weekday-light.png` | Weekday, light — Friday 7:12 AM PT, three sessions open |
| `7b-weekday-dark.png` | Weekday, dark — same moment |
| `7c-weekend-light.png` | Weekend, light — Saturday 11:40 AM PT, nothing trading |
| `row-states.png` | All row states at production row height |

The desk background and menu bar in the popover captures are staging for the mock — only the 390×590 panel and the status-item label are the design.

## Files

| File | What it is |
| --- | --- |
| `Market Sessions.dc.html` | The design. **Turn 7 (`7a`, `7b`, `7c`) is current;** Turns 1–6 above/below it are earlier iterations kept as history — ignore them. |
| `support.js` | Runtime for the HTML prototype. Not part of the design. |

Open the HTML in a browser and scroll to the top section, "Turn 7 — Your five calls, built".

## Open questions

Two things this design does not settle:

1. **Ring direction is ambiguous at 14pt.** Filling and draining arcs look identical; the closed state is dimmed to 0.62 to disambiguate. If that proves too subtle in the real menu bar, the fallback is a hairline or dotted track for the closed state.
2. **Accessibility text sizes.** The design is drawn at default size only. Six 44pt rows exactly fill 590pt with no scroll — at larger accessibility sizes the list will need to scroll, or the open-now grid will need to collapse first.
3. **Four simultaneous open sessions** breaks the open-now grid and overflows the list. See "Cases the design does not draw" — this one needs a decision before implementation, not after.

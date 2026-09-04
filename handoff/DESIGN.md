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
Primary text rgba(0,0,0,0.85); secondary rgba(0,0,0,0.55); hairline rgba(0,0,0,0.07–0.08). No green, no blue, in the popover. Dark mode: white at 0.92 / 0.50 / 0.09 respectively.

## Menu-bar label (10a)
One 14pt ring (3.5 stroke, track 22% black, fill primary label colour, fraction = elapsed of the next-to-change session) + its 3-letter code, 12pt medium. Template image so it inverts with the bar. Tooltip: full name + "Closes 7:30 PM".

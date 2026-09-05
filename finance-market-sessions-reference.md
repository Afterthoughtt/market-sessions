# Finance Market Sessions Reference

Last audited: `2026-09-05`

Target display timezone: `America/Vancouver`

Implementation note: do not hardcode Vancouver clock times as the source of truth. Store each session in its canonical timezone and convert dynamically to `America/Vancouver` so DST changes are handled correctly.

## Core Sessions

| Session | Canonical Time Zone | Open | Main Close | Active Days | Crypto Impact |
|---|---|---:|---:|---|---|
| CME Globex — ES/NQ/YM/RTY/Treasuries/Gold/Oil | `America/Chicago` | 5:00 PM CT | 4:00 PM CT next day | Sun–Fri | Very high |
| Tokyo Stock Exchange | `Asia/Tokyo` | 9:00 AM JST | 3:30 PM JST | Mon–Fri | Medium |
| Hong Kong Exchange | `Asia/Hong_Kong` | 9:30 AM HKT | 4:00 PM HKT continuous; closing auction ends randomly 4:08–4:10 PM HKT | Mon–Fri | Medium |
| Shanghai Stock Exchange | `Asia/Shanghai` | 9:30 AM CST | 3:00 PM CST | Mon–Fri | Medium |
| London Stock Exchange | `Europe/London` | 8:00 AM | 4:30 PM | Mon–Fri | High |
| New York FX liquidity session (convention) | `America/New_York` | ~8:00 AM ET | ~5:00 PM ET | Mon–Fri | High |
| NYSE / Nasdaq Cash Session | `America/New_York` | 9:30 AM ET | 4:00 PM ET | Mon–Fri | Very high |
| Spot FX weekly liquidity (OTC convention) | `America/New_York` | ~5:00 PM Sun ET | ~5:00 PM Fri ET | Sun–Fri | High |
| Crypto UTC Daily Candle | `UTC` | 12:00 AM UTC | 12:00 AM UTC next day | Daily | Very high |

## Vancouver Schedule — PDT Reference

These are the Vancouver times while `America/Vancouver` is on PDT (`UTC-7`).

| Vancouver Time | Event |
|---:|---|
| 12:00 AM | London / Europe cash open |
| 5:00 AM | New York FX session begins approximately |
| 5:30 AM | Major 8:30 AM ET U.S. economic data window, when scheduled |
| 6:30 AM | NYSE / Nasdaq cash open |
| 8:30 AM | London / Europe cash close |
| 1:00 PM | NYSE / Nasdaq cash close; major CME equity-index settlement window |
| 2:00 PM | CME traditional macro futures daily maintenance begins; CME crypto 2-minute maintenance begins |
| 3:00 PM | CME traditional macro futures reopen |
| 5:00 PM | Crypto UTC daily candle close |
| 5:00 PM | Tokyo session opens |
| 6:30 PM | Hong Kong and Shanghai sessions open |
| 11:30 PM | Tokyo session closes |
| 12:00 AM | Shanghai session closes |
| 1:00 AM | Hong Kong continuous session closes; closing auction completes around 1:08–1:10 AM |

## Weekly Schedule

### Sunday

```text
2:00 PM  Spot FX weekly liquidity begins approximately; exact broker access varies (OANDA reference: 2:05 PM)
3:00 PM  CME traditional macro futures weekly open (ES/NQ/YM/RTY/Treasuries/Gold/Oil)
5:00 PM  Crypto daily candle close
5:00 PM  Crypto weekly candle close
5:00 PM  New crypto week begins
5:00 PM  Tokyo Monday session opens
6:30 PM  Hong Kong Monday session opens
6:30 PM  Shanghai Monday session opens
11:30 PM Tokyo session closes
```

### Monday

```text
12:00 AM Shanghai session closes
12:00 AM London / Europe opens
1:00 AM  Hong Kong continuous session closes; closing auction completes around 1:08–1:10 AM
5:00 AM  New York FX session begins approximately
5:30 AM  U.S. 8:30 AM ET economic data window, when scheduled
6:30 AM  NYSE / Nasdaq open
8:30 AM  London / Europe close
1:00 PM  NYSE / Nasdaq close
1:00 PM  Major CME equity-index settlement window
2:00 PM  CME traditional macro futures maintenance begins; CME crypto maintenance 2:00–2:02 PM
3:00 PM  CME traditional macro futures reopen
5:00 PM  Crypto daily candle close
5:00 PM  Tokyo Tuesday session opens
6:30 PM  Hong Kong Tuesday session opens
6:30 PM  Shanghai Tuesday session opens
11:30 PM Tokyo session closes
```

### Tuesday

```text
12:00 AM Shanghai session closes
12:00 AM London / Europe opens
1:00 AM  Hong Kong continuous session closes; closing auction completes around 1:08–1:10 AM
5:00 AM  New York FX session begins approximately
5:30 AM  U.S. 8:30 AM ET economic data window, when scheduled
6:30 AM  NYSE / Nasdaq open
8:30 AM  London / Europe close
1:00 PM  NYSE / Nasdaq close
1:00 PM  Major CME equity-index settlement window
2:00 PM  CME traditional macro futures maintenance begins; CME crypto maintenance 2:00–2:02 PM
3:00 PM  CME traditional macro futures reopen
5:00 PM  Crypto daily candle close
5:00 PM  Tokyo Wednesday session opens
6:30 PM  Hong Kong Wednesday session opens
6:30 PM  Shanghai Wednesday session opens
11:30 PM Tokyo session closes
```

### Wednesday

```text
12:00 AM Shanghai session closes
12:00 AM London / Europe opens
1:00 AM  Hong Kong continuous session closes; closing auction completes around 1:08–1:10 AM
5:00 AM  New York FX session begins approximately
5:30 AM  U.S. 8:30 AM ET economic data window, when scheduled
6:30 AM  NYSE / Nasdaq open
8:30 AM  London / Europe close
1:00 PM  NYSE / Nasdaq close
1:00 PM  Major CME equity-index settlement window
2:00 PM  CME traditional macro futures maintenance begins; CME crypto maintenance 2:00–2:02 PM
3:00 PM  CME traditional macro futures reopen
5:00 PM  Crypto daily candle close
5:00 PM  Tokyo Thursday session opens
6:30 PM  Hong Kong Thursday session opens
6:30 PM  Shanghai Thursday session opens
11:30 PM Tokyo session closes
```

### Thursday

```text
12:00 AM Shanghai session closes
12:00 AM London / Europe opens
1:00 AM  Hong Kong continuous session closes; closing auction completes around 1:08–1:10 AM
5:00 AM  New York FX session begins approximately
5:30 AM  U.S. 8:30 AM ET economic data window, when scheduled
6:30 AM  NYSE / Nasdaq open
8:30 AM  London / Europe close
1:00 PM  NYSE / Nasdaq close
1:00 PM  Major CME equity-index settlement window
2:00 PM  CME traditional macro futures maintenance begins; CME crypto maintenance 2:00–2:02 PM
3:00 PM  CME traditional macro futures reopen
5:00 PM  Crypto daily candle close
5:00 PM  Tokyo Friday session opens
6:30 PM  Hong Kong Friday session opens
6:30 PM  Shanghai Friday session opens
11:30 PM Tokyo weekly session closes
```

### Friday

```text
12:00 AM Shanghai weekly session closes
12:00 AM London / Europe opens
1:00 AM  Hong Kong continuous weekly session closes; closing auction completes around 1:08–1:10 AM
5:00 AM  New York FX session begins approximately
5:30 AM  U.S. 8:30 AM ET economic data window, when scheduled
6:30 AM  NYSE / Nasdaq open
8:30 AM  London / Europe weekly close
1:00 PM  NYSE / Nasdaq weekly close
1:00 PM  Major CME equity-index settlement window
2:00 PM  CME traditional macro futures weekly close
2:00 PM  Spot FX weekly liquidity ends approximately; exact broker cutoff varies (OANDA reference: 1:59 PM)
5:00 PM  Crypto daily candle close
```

### Saturday

```text
12:00 AM CME 24/7 crypto-futures weekly maintenance begins
2:00 AM  CME 24/7 crypto-futures weekly maintenance ends
5:00 PM  Crypto daily candle close
```

### CME Crypto Futures Maintenance

CME's flagship cryptocurrency futures and options have traded on a 24/7 schedule since May 29, 2026, except for scheduled maintenance:

```text
Monday–Friday:
2:00 PM–2:02 PM Vancouver while PDT
4:00 PM–4:02 PM CT

Saturday:
12:00 AM–2:00 AM Vancouver while PDT
2:00 AM–4:00 AM CT
```

There is no traditional Friday-close/Sunday-open gap for these CME crypto products. The normal CME macro-futures weekly open and close still apply to products such as ES, NQ, YM, RTY, Treasuries, Gold and WTI.

## Candle Closes

### Crypto

Canonical reference timezone: `UTC`

Use this for the standard UTC-aligned crypto candle boundary used by major venues/data products. If the app later displays venue-specific candles, verify that venue's candle anchor separately.

```text
Daily candle close:
Every day at 12:00 AM UTC
5:00 PM Vancouver while on PDT
4:00 PM Vancouver while on PST

Weekly candle close:
Sunday at the Vancouver equivalent of Monday 12:00 AM UTC
5:00 PM Sunday while on PDT
4:00 PM Sunday while on PST

New weekly candle:
Immediately after the weekly close
```

### U.S. Equities

Canonical source timezone: `America/New_York`

```text
Daily cash-session close:
4:00 PM ET
1:00 PM Vancouver

Weekly cash-session close:
Friday at 4:00 PM ET
Friday at 1:00 PM Vancouver
```

### CME Equity Index Futures

Canonical source timezone: `America/Chicago`

```text
Daily settlement window:
Approximately 3:00 PM CT
Approximately 1:00 PM Vancouver

Daily maintenance / session boundary:
4:00 PM–5:00 PM CT
2:00 PM–3:00 PM Vancouver

Weekly open:
Sunday 5:00 PM CT
Sunday 3:00 PM Vancouver

Weekly close:
Friday 4:00 PM CT
Friday 2:00 PM Vancouver
```

## Minimal First-Class Events

For a minimal menu-bar implementation, prioritize these:

```text
00:00  London / Europe Open
05:30  U.S. Major Macro Data Window
06:30  New York Cash Open
08:30  London / Europe Close
13:00  New York Cash Close / CME Settlement Window
14:00  CME Traditional Futures Maintenance; CME Crypto 2-Minute Maintenance
15:00  CME Traditional Futures Open
17:00  Crypto UTC Daily Close
17:00  Tokyo Open
18:30  Hong Kong / Shanghai Open
23:30  Tokyo Close
00:00  Shanghai Close
01:00  Hong Kong Continuous Close
```

Weekly-specific events:

```text
Sunday 14:00  Spot FX Weekly Open, approximately (broker-specific; OANDA 14:05 PDT)
Sunday 15:00  CME Traditional Futures Weekly Open
Sunday 17:00  Crypto Weekly Close / New Week

Friday 08:30  London / Europe Weekly Close
Friday 13:00  U.S. Cash Weekly Close
Friday 14:00  CME Traditional Futures Weekly Close / Spot FX Weekly Close approximately (OANDA 13:59 PDT)

Saturday 00:00–02:00  CME Crypto Maintenance
```

## Suggested Session Priority

1. New York cash open
2. CME traditional futures weekly/daily open
3. London / Europe open
4. U.S. 8:30 AM ET macro-data window
5. New York cash close / CME settlement
6. Crypto UTC daily and weekly candle close
7. Tokyo open
8. Hong Kong / Shanghai open
9. London close
10. Asia session closes

## Audit Notes

- NYSE and Nasdaq regular cash trading: 9:30 AM–4:00 PM ET. Extended hours (NYSE Arca early trading, Nasdaq pre-market): 4:00–9:30 AM ET; after-hours: 4:00–8:00 PM ET.
- CME core equity-index futures such as ES/NQ trade Sunday–Friday from 5:00 PM CT to 4:00 PM CT with a 4:00 PM–5:00 PM CT maintenance boundary.
- The old 3:15 PM–3:30 PM CT CME equity-index halt was eliminated effective June 28, 2021 for ES, NQ, RTY, YM and the other affected CME/CBOT equity products. Do not implement that obsolete halt.
- CME equity-index daily settlement for ES/NQ-family products is determined around 4:00 PM ET / 3:00 PM CT, corresponding to 1:00 PM Vancouver when on PDT.
- TSE cash trading: 9:00–11:30 AM and 12:30–3:30 PM JST. Orders are accepted from 8:00 AM (morning) and 12:05 PM (afternoon) with no matching before each session opens.
- HKEX pre-opening auction session: 9:00–9:30 AM HKT. Continuous trading: 9:30 AM–12:00 PM and 1:00–4:00 PM HKT; the closing auction ends randomly between 4:08 and 4:10 PM HKT.
- SSE stocks: opening auction 9:15–9:25 AM; continuous trading 9:30–11:30 AM and 1:00–2:57 PM; closing auction 2:57–3:00 PM China time.
- LSE Main Market regular trading remains 8:00 AM–4:30 PM London time. SETS opening auction call 7:50–8:00 AM; closing auction 4:30–4:35 PM, closing price crossing 4:35–4:40 PM. No continuous trading outside 8:00 AM–4:30 PM.
- Pre-open windows and U.S. extended hours above were verified 2026-09-05 against the exchange pages in Primary References.
- Spot FX is OTC and has no single exchange bell. Use approximately 5:00 PM ET Sunday to 5:00 PM ET Friday as the global convention; broker execution windows can differ by minutes. OANDA's current reference is Sunday 5:05 PM ET to Friday 4:59 PM ET.
- Crypto UTC daily candles use a 00:00 UTC boundary on major data venues such as Coinbase. The standard weekly reference in this file is Monday 00:00 UTC / Sunday local evening.
- Holiday and early-close calendars override all normal recurring schedules.

## Implementation Rules

- Use canonical IANA time zones for every market.
- Convert dynamically to `America/Vancouver`.
- Do not hardcode PDT/PST offsets.
- Support exchange holidays separately from normal weekly schedules.
- Treat spot FX open/close times as approximate because FX is decentralized.
- Treat the U.S. 8:30 AM ET macro window as an event window, not a guaranteed daily release.
- Crypto UTC candle boundaries should always be calculated from UTC, not local time.

## Primary References

- CME Group trading hours: https://www.cmegroup.com/trading-hours.html
- CME 2021 equity-index halt elimination filing: https://www.cmegroup.com/market-regulation/rule-filings/2021/6/21-244R_2.pdf
- CME 24/7 cryptocurrency futures FAQ: https://www.cmegroup.com/articles/faqs/frequently-asked-questions-cryptocurrency-futures.html
- NYSE hours and calendars (Arca early and late trading): https://www.nyse.com/markets/hours-calendars
- Nasdaq U.S. market hours: https://www.nasdaq.com/market-activity/stock-market-holiday-schedule
- London Stock Exchange market structure and trading hours (SETS auction times): https://docs.londonstockexchange.com/sites/default/files/documents/n1819_attach1.pdf
- Japan Exchange Group domestic stock trading rules: https://www.jpx.co.jp/english/equities/trading/domestic/01.html
- HKEX securities market trading hours: https://www.hkex.com.hk/Services/Trading-hours-and-Severe-Weather-Arrangements/Trading-Hours/Securities-Market?sc_lang=en
- Shanghai Stock Exchange trading schedule: https://english.sse.com.cn/start/trading/schedule/
- OANDA Canada FX hours: https://www.oanda.com/ca-en/trading/hours-of-operation/
- Coinbase daily OHLCV UTC boundary: https://help.coinbase.com/en/data-marketplace/getting-started/data-marketplace-products

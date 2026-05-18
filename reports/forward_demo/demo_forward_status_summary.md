# Demo Forward Status Summary

Update this file daily from `daily_summary_*.csv` and deal-level logs.

## Current Status

| Item | Value |
|---|---:|
| Demo start date | TBD |
| Total demo days | 0 |
| Total closed trades | 0 |
| Total realized R | 0.0000 |
| ExpectancyR | 0.0000 |
| PF | 0.0000 |
| AvgLossR | 0.0000 |
| MaxDD% | 0.0000 |
| MaxDD_R | 0.0000 |
| live errors | 0 |
| DD% stop events | 0 |
| Period R stop events | 0 |

## Tester Baseline

| Baseline | Trades | ExpectancyR | PF | MaxDD% | Live errors |
|---|---:|---:|---:|---:|---:|
| 2025 production guard | 92 | +0.2014 | 1.3797 | 2.9744 | 0 |
| 2026 Jan-Apr production guard | 38 | +0.1729 | 1.3249 | 1.6717 | 0 |


## Demo Gate

Pass only when:

- closed trades >= 30-50
- ExpectancyR > 0
- PF > 1.05
- AvgLossR near -1R
- live errors = 0
- deal-level logging is complete
- DD% stops do not fire under normal conditions
- period R guard events are explainable

## Current Decision

Controlled demo not yet complete. Small live and full production remain blocked.

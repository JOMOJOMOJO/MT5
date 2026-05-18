# 2026-05-14 - ExpectedValue NWave USDJPY Causal Splits

## Common Setup

- EA: `ExpectedValue_NWave_Scalper`
- Symbol / period: `USDJPY / M5`
- Window: `2025.12.31` to `2026.03.30`
- Mode: `EnableTrading=false`
- Context / Pattern / Entry TF: `H4 / M15 / M5`
- Extension filter: `FILTER_ALL`
- Conservative same-bar exit: `true`

## Run Definitions

| Run | MaxManagedPositions | TakeProfitRMultiple | MagicNumber |
| --- | ---: | ---: | ---: |
| A | 1 | 1.5 | 2026051411 |
| B | 2 | 1.5 | 2026051412 |
| C | 1 | 1.2 | 2026051413 |
| D | 1 | 2.0 | 2026051414 |

## Main Results

| Run | Closed virtual trades | Win rate | AvgWinR | AvgLossR | ExpectancyR | ProfitFactor | Max consecutive losses | MaxDD_R | LongExpectancyR | ShortExpectancyR |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 194 | 38.14% | 1.5000 | -1.0000 | -0.0464 | 0.9250 | 11 | 24.99 | -0.0195 | -0.0762 |
| B | 321 | 41.74% | 1.5001 | -1.0000 | 0.0436 | 1.0749 | 9 | 13.00 | 0.0804 | 0.0062 |
| C | 190 | 46.32% | 1.2015 | -1.0000 | 0.0196 | 1.0366 | 9 | 22.55 | 0.0127 | 0.0274 |
| D | 143 | 27.97% | 2.0000 | -1.0000 | -0.1608 | 0.7767 | 9 | 27.00 | 0.0286 | -0.3425 |

## Session ExpectancyR

| Run | asia | london | new_york | late_us |
| --- | ---: | ---: | ---: | ---: |
| A | -0.0219 | -0.0514 | -0.0626 | -0.1671 |
| B | 0.1441 | -0.0590 | 0.0395 | -0.1668 |
| C | 0.0484 | 0.0105 | -0.0094 | 0.1006 |
| D | -0.1346 | 0.0976 | -0.4000 | 0.0000 |

## Direction x Session ExpectancyR

| Run | LONG asia | LONG london | LONG new_york | LONG late_us | SHORT asia | SHORT london | SHORT new_york | SHORT late_us |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 0.0898 | -0.2499 | 0.1291 | -1.0000 | -0.1671 | 0.1612 | -0.2426 | 1.4986 |
| B | 0.1539 | -0.1488 | 0.2779 | -0.5000 | 0.1319 | 0.0328 | -0.1520 | 0.2496 |
| C | 0.1290 | -0.0891 | 0.0221 | -0.4497 | -0.0825 | 0.1008 | -0.0370 | 1.2012 |
| D | -0.0357 | 0.5000 | -0.3182 | 0.0000 | -0.2500 | -0.2857 | -0.4643 | 0.0000 |

## Reject Counts

| Run | Total rejected | max_positions_blocked | consecutive_loss_blocked | spread_too_wide | fibo_filter_failed | rr_too_low | daily_loss_blocked |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 696 | 554 | 97 | 36 | 9 | 0 | 0 |
| B | 484 | 279 | 123 | 36 | 9 | 0 | 37 |
| C | 703 | 197 | 29 | 14 | 9 | 454 | 0 |
| D | 750 | 628 | 77 | 36 | 9 | 0 | 0 |

## MFE / MAE / Holding Diagnostics

| Run | Losses | Losing trades with MFE_R >= 0.5 | Losing trades with MFE_R >= 1.0 | Winning avg MAE_R | HoldingBars avg | HoldingBars median | HoldingBars max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 120 | 51 | 15 | -0.4943 | 56.96 | 23 | 925 |
| B | 187 | 77 | 21 | -0.5146 | 51.48 | 22 | 925 |
| C | 102 | 34 | 6 | -0.5180 | 38.91 | 16 | 383 |
| D | 103 | 52 | 28 | -0.5276 | 84.62 | 38 | 925 |

## Read

- Run B shows that `max_positions_blocked` materially affected observed expectancy. Allowing two managed positions changed expectancy from `-0.0464R` to `+0.0436R`, reduced `max_positions_blocked` from `554` to `279`, and increased closed inventory from `194` to `321`.
- Run C shows that `1.2R` exits improve win rate and produce slightly positive expectancy, but `rr_too_low=454` means the current SL/TP normalization plus `MinRR=1.2` rejects many candidates. This is not a pure TP-only comparison.
- Run D is clearly worse at `2.0R`, mainly because win rate falls to `27.97%` and short expectancy deteriorates to `-0.3425R`.
- Direction/session pockets worth studying later are visible in Run B: `LONG new_york`, `LONG asia`, `SHORT asia`, and `SHORT london` are positive, while `SHORT new_york` and `LONG london` remain weak.
- A large fraction of losing trades had meaningful favorable excursion before stopping out. In Run A, `51/120` losers reached at least `0.5R` MFE; in Run D, `28/103` losers reached at least `1.0R` MFE. This points to exit-path diagnostics as a future validation topic, not an immediate rule change.

## Artifacts

- Run A diagnostics: `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-causal-splits/run-a/diagnostics.csv`
- Run B diagnostics: `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-causal-splits/run-b/diagnostics.csv`
- Run C diagnostics: `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-causal-splits/run-c/diagnostics.csv`
- Run D diagnostics: `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-causal-splits/run-d/diagnostics.csv`

# 2026-06-03 - Multi-Currency Score Scanner Log Lightweight

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: reduce diagnostic CSV output without adding inputs or changing trading behavior.
- Purpose: speed up backtests, especially `LONG_ONLY + DowFractalStructureFilter`.

## Changes

- No new input parameter was added.
- Score diagnostics now write only:
  - best candidates
  - entry-score candidates
  - order blocked rows
  - order attempts
  - order sent or failed rows
- Structure diagnostics now write only:
  - best candidates
  - entry-score candidates
  - structure-pass candidates
  - order blocked rows
  - order attempts
  - order sent or failed rows
- Full structure fail counts are retained through internal counters and a new per-run structure summary CSV.
- Scan diagnostics CSV remains unchanged.
- Trading logic, score calculation, Dow/fractal structure judgement, TP/SL, CTrade order bridge, and risk calculation were not changed.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner.log`
- Compile result: `0 errors, 0 warnings`
- Rerun 2025 A/B/D:
  - A: BOTH + M5 new-bar scan
  - B: LONG_ONLY + M5 new-bar scan
  - D: LONG_ONLY + Dow/fractal structure + M5 new-bar scan

## Results

| Run | Old Elapsed | New Elapsed | Trades | PF | Expected Payoff | Net | Max DD |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 3804s | 1160s | 1690 | 0.982 | -0.44 | -750.91 | 36.06% |
| B | 3826s | 1160s | 1184 | 1.109 | 3.19 | 3777.82 | 19.26% |
| D | 6633s | 1334s | 675 | 1.159 | 4.96 | 3349.91 | 6.64% |

## Log Size

| Run | Old Score CSV | New Score CSV | Old Structure Detail CSV | New Structure Detail CSV |
|---|---:|---:|---:|---:|
| A | 67.81 MB | 19.23 MB | 0 MB | 0 MB |
| B | 81.89 MB | 23.10 MB | 0 MB | 0 MB |
| D | 161.92 MB | 44.91 MB | 55.44 MB | 17.19 MB |

The D structure summary CSV is `0.41 KB` and still records all `515536` structure evaluations, `168274` detail rows, pass count, fail count, `10.54%` pass rate, and `no_trend_up` as the top fail reason.

## Decision

- The log-lightweight change is behavior-preserving for A/B/D trade metrics.
- D runtime improved by about `79.9%` versus the previous phase 2 D run.
- Structure detail CSV is still non-trivial because best candidates and structure-pass candidates are intentionally retained, but the full fail flood is removed.

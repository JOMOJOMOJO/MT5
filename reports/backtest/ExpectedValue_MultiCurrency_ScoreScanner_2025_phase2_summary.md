# ExpectedValue MultiCurrency ScoreScanner - 2025 Phase 2 Summary

## Scope

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Test year: 2025.01.01 - 2025.12.31
- Model: MT5 real ticks, chart symbol `USDJPY`, period `M5`
- Purpose: speed up diagnostic backtests, split winning and losing branches, and test a first Dow/fractal structure gate.
- Research risk stops: daily, weekly, and max drawdown stops were disabled by setting very high limits in the phase 2 presets. This keeps the 2025 full-year behavior visible.

## Implementation

- `InpScanSeconds` default changed to `300`.
- `InpScanOnlyOnNewExecutionBar=true` added. With this enabled, `OnTimer` scans only after a new closed `InpExecutionTF` bar is detected.
- Scan diagnostics CSV added with `scan_executed_new_execution_bar`, `scan_skipped_same_execution_bar`, `last_scan_bar_time`, and `scan_elapsed_ms`.
- Score diagnostics CSV is now lightweight. It writes only best candidates, entry-score candidates, order attempts, order blocked rows, and order results.
- Research branch inputs added:
  - `InpTradeDirectionMode`: `BOTH`, `LONG_ONLY`, `SHORT_ONLY`
  - `InpDisableUsdJpyShort`
  - `InpSymbolResearchMode`: `ALL`, `XAUUSD_ONLY`, `FX_ONLY`
- Dow/fractal structure filter added behind `InpUseDowFractalStructureFilter=false` by default.
- Structure diagnostics CSV is now lightweight. It writes only best candidates, entry-score candidates, structure-pass candidates, order attempts, order blocked rows, and order results.
- Structure summary CSV keeps the full structure-evaluation counts and failure-reason counts, including `no_trend_up`, `pullback_too_deep`, `pullback_not_valid`, `no_reclaim`, `structure_pass`, `structure_fail`, pass rate, and top failure reason.
- No new input parameter was added for the log-lightweight change.
- Existing CTrade bridge, risk sizing, base score calculation, TP, and SL placement were not changed.

## Verification

- Compile: `0 errors, 0 warnings`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner.log`
- Backtests completed for A-F presets.

## Baseline Check

The first comparison is whether the M5 new-bar scan changed the prior full-year no-stop behavior.

| Run | Trades | PF | Expected Payoff | Net | Max DD | Elapsed |
|---|---:|---:|---:|---:|---:|---:|
| Previous no-stops, timer scan | 1692 | 0.984 | -0.40 | -672.91 | 35.44% | 5578s |
| A: BOTH + M5 new-bar scan + lightweight logs | 1690 | 0.982 | -0.44 | -750.91 | 36.06% | 1160s |

Judgement: the M5 new-bar scan and lightweight logs did not materially change the full-year behavior. The BOTH strategy still has no positive expectancy, but the recorded A-run time is now much lower.

## Scenario Results

| Run | Scenario | Elapsed | Trades | Win Rate | PF | Expected Payoff | Net | Max DD | XAU Share | USDJPY Short Net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A | BOTH + 5m | 1160s | 1690 | 40.00% | 0.982 | -0.44 | -750.91 | 36.06% | 72.25% | -2297.25 |
| B | LONG_ONLY + 5m | 1160s | 1184 | 42.65% | 1.109 | 3.19 | 3777.82 | 19.26% | 77.28% | 0.00 |
| C | SHORT_ONLY + 5m | 3784s | 757 | 35.80% | 0.817 | -4.53 | -3428.37 | 37.30% | 50.86% | -2173.97 |
| D | LONG_ONLY + structure + 5m | 1334s | 675 | 44.15% | 1.159 | 4.96 | 3349.91 | 6.64% | 79.11% | 0.00 |
| E | XAUUSD_ONLY + LONG_ONLY + structure + 5m | 3778s | 549 | 44.44% | 1.171 | 5.25 | 2880.52 | 7.00% | 100.00% | 0.00 |
| F | BOTH + disable USDJPY short + 5m | 3784s | 1566 | 41.44% | 1.054 | 1.43 | 2237.56 | 24.60% | 81.74% | 0.00 |

Note: A, B, and D were rerun after log-lightweight changes. C, E, and F remain from the earlier phase 2 run.

## Log Lightweight Validation

| Run | Old Elapsed | New Elapsed | Old Score CSV | New Score CSV | Old Structure Detail CSV | New Structure Detail CSV | Structure Summary |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 3804s | 1160s | 67.81 MB | 19.23 MB | 0 MB | 0 MB | 0.36 KB |
| B | 3826s | 1160s | 81.89 MB | 23.10 MB | 0 MB | 0 MB | 0.36 KB |
| D | 6633s | 1334s | 161.92 MB | 44.91 MB | 55.44 MB | 17.19 MB | 0.41 KB |

The D run kept identical trade metrics after logging was reduced: `675` trades, `PF 1.159`, `Expected Payoff 4.96`, `Net 3349.91`, and `Max DD 6.64%`. Runtime improved from `6633s` to `1334s`, about `79.9%` faster. Structure detail rows dropped from `515536` to `168274`, while the summary CSV still records all `515536` structure evaluations and the same `10.54%` pass rate.

## Branch Findings

### Direction

| Run | Direction | Trades | PF | Expected Payoff | Net |
|---|---|---:|---:|---:|---:|
| A | LONG | 1066 | 1.106 | 2.48 | 2641.86 |
| A | SHORT | 624 | 0.798 | -5.44 | -3392.77 |
| B | LONG | 1184 | 1.109 | 3.19 | 3777.82 |
| C | SHORT | 757 | 0.817 | -4.53 | -3428.37 |
| D | LONG | 675 | 1.159 | 4.96 | 3349.91 |
| F | SHORT, USDJPY short removed | 436 | 0.883 | -3.24 | -1411.02 |

The main failure is not the scanner as a whole; it is the current SHORT branch. Removing only USDJPY short flips total net positive, but the remaining short side is still negative. SHORT should be parked or rebuilt as a separate strategy, not kept as a normal branch.

### Symbol

- A/BOTH: `USDJPY` lost `-2373.99`; `USDJPY:SHORT` alone lost `-2297.25`.
- A/BOTH: `XAUUSD` made `+2049.33`, but had `72.25%` of all trades.
- B/LONG_ONLY: `XAUUSD` made `+4053.39`; `USDJPY` was near flat at `+32.15`; `EURJPY` was poor at `-603.08`.
- D/LONG+structure: `XAUUSD` made `+2874.71`; `USDJPY` improved to `+539.69`; `EURJPY` and `EURUSD` remained weak.
- E/XAU+LONG+structure: all profit came from one symbol. This is useful as a research branch, not as proof of diversified robustness.

### Month

- A/BOTH weak months: February `-940.98`, March `-646.02`, June `-647.41`, August `-948.16`.
- B/LONG_ONLY weak months: February `-777.61`, June `-589.08`, August `-975.79`.
- D/LONG+structure still loses in February `-308.53`, June `-404.54`, and August `-532.12`, but drawdown is much smaller.
- E/XAU+LONG+structure still loses in June `-571.16` and August `-409.26`.

The structure gate reduces damage, but it does not eliminate regime-sensitive months. Month/session filtering should be treated as a later diagnostic layer, not tuned immediately.

### Score Band

- A/BOTH `75-80` score band lost `-994.42`.
- B/LONG_ONLY `65-70` and `70-75` were strong, but `75-80` and `80+` were negative.
- D/E structure runs also showed negative `75+` score bands.

The score is not monotonic. Higher score does not reliably mean higher expectancy. The next phase should inspect why high-score entries cluster in bad regimes instead of simply raising thresholds.

### Structure Filter

| Run | Structure Rows | Pass Rate | Top Fail Reason |
|---|---:|---:|---|
| D: LONG_ONLY + structure | 515536 evaluations / 168274 detail rows | 10.54% | `no_trend_up` |
| E: XAUUSD_ONLY + LONG_ONLY + structure | 73648 | 12.66% | `no_trend_up` |

Top D failure reasons:

- `no_trend_up`: 349872
- `no_reclaim`: 94776
- `pullback_too_deep`: 12925
- `pullback_not_valid`: 3629

The filter is restrictive but not empty. It cut B's `1184` LONG trades to D's `675` trades, improved PF from `1.109` to `1.159`, improved expected payoff from `3.19` to `4.96`, and reduced max DD from `19.26%` to `6.64%`.

## Answers

- Does the strategy recover without stop conditions? As BOTH, no. The no-stop full year remains negative and high-DD.
- Is there recovery value in isolated branches? Yes. LONG-only is positive, and LONG+structure is materially cleaner.
- Is the main cause a specific branch? Yes. SHORT is the primary loss branch, with USDJPY short the largest single damage source.
- Is XAUUSD dependency material? Yes. The profitable branches depend heavily on XAUUSD, especially E at 100%.
- First branch to cut: current SHORT branch. If BOTH must remain for research, cut at least USDJPY SHORT first, but that is not sufficient as a final fix.
- First branch to continue: `LONG_ONLY + DowFractalStructureFilter`; separately track `XAUUSD_ONLY + LONG_ONLY + DowFractalStructureFilter` as the cleanest but concentrated branch.

## Next Phase Priority

1. Validate `LONG_ONLY + DowFractalStructureFilter` and `XAUUSD_ONLY + LONG_ONLY + DowFractalStructureFilter` across other years before optimizing.
2. Park the current SHORT branch or rebuild it independently. Do not keep current SHORT as a production branch.
3. Run a controlled test for excluding or separately gating weak LONG symbols, especially `EURJPY`.
4. Investigate why high score bands above `75` underperform; do not raise score thresholds blindly.
5. Add session and regime diagnostics after OOS checks, focusing on February, June, August and weak hours such as 11, 12, 15, and 23.
6. Reduce structure diagnostic overhead for future long runs, for example by logging detailed structure rows only for best candidates or entry-score candidates.

## Artifacts

- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_run_comparison.csv`
- Trades CSVs: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_*_trades.csv`
- Symbol aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_symbol.csv`
- Direction aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_direction.csv`
- Symbol-direction aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_symbol_direction.csv`
- Month aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_month.csv`
- Hour aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_hour.csv`
- Score-band aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_score_band.csv`
- Scan diagnostics summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_scan_diagnostics_summary.csv`
- Structure diagnostics summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_structure_filter_summary.csv`
- Per-run structure summary CSVs: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_*_structure_summary.csv`
- Structure failure reasons: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_structure_filter_by_reason.csv`
- Combined trade/score join: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_trade_join.csv`
- Analyzer: `scripts/analyze_multicurrency_score_scanner_phase2.py`
- Runner: `scripts/run_multicurrency_score_scanner_phase2_backtests.ps1`

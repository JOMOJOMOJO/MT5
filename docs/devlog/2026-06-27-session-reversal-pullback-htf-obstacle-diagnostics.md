# 2026-06-27 Session Reversal Pullback HTF Wave Alignment Diagnostics

## Task

Refine `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` so session labels are not exclusive, London first60/first120 is evaluated at UTC 07:00-08:59, Tokyo is JPY-only, and entries require H4/H1 higher-timeframe wave3 alignment before taking M15/M5 first-pullback reversal patterns.

## Prior Evidence Used

- `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/summary.md` showed confirmed wave3 breaks were materially better than unconfirmed early wave3 entries.
- `reports/backtest/runs/20260623_fxelliott_roadmap_diagnostics/summary.md` also showed `wave3_break_confirmed=false` was materially worse.
- `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/summary.md` showed obstacle filters can over-prune trade count without creating expectancy.
- `knowledge/experiments/2026-04-13-usdjpy-method2-triple-structure-postmortem-redesign.md` supported avoiding neckline-break chase entries and requiring retest/acceptance.

## Implementation

- Changed session detection from exclusive `if/else` labeling to independent UTC start windows:
  - Tokyo UTC 00:00 start
  - London UTC 07:00 start
  - Overlap UTC 13:00 start
  - New York UTC 16:00 start
- Added Tokyo-only symbol gating for `USDJPY, EURJPY, GBPJPY, AUDJPY`.
- Exported `session_candidate_symbol_map` to signals/trades and breakdown CSV.
- Added H4/H1 confirmed fractal-style wave3 direction diagnostics and a default hard gate requiring both HTFs to match the entry direction.
- Kept M15 first-pullback/retest patterns and added M5 fallback as a lower-timeframe wave3 source.
- Reclassified already-broken neckline/opening range/session high-low levels as `retest_reference_*` instead of target-path obstacles.

## Validation

- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_compile.txt`
- Compile result: `0 errors, 0 warnings`.
- MT5 2025 shallow BT was rerun for all 11 scenarios with:
  - M15
  - Model 4
  - Deposit 10000
  - `C:\Program Files\XMTrading MT5\terminal64.exe`
- The first attempted BT used the wrong terminal install (`XMTrading MT5 - 2`) and failed with `tester EX5 not found`; the rerun used the terminal tied to this repo data folder.

## Result

No scenario passed the 2025 shallow gate.

Key outcomes:

| Scenario | Trades | PF | avg_R | Net |
|---|---:|---:|---:|---:|
| all_symbols_first120 | 163 | 0.81 | -0.1008 | -381.38 |
| one_symbol_first120 | 116 | 0.87 | -0.0600 | -174.63 |
| one_symbol_first60 | 93 | 0.80 | -0.1011 | -229.68 |
| clean_target_path_first120 | 23 | 1.01 | +0.0015 | +2.02 |
| tokyo_first120_reference | 18 | 1.05 | +0.0227 | +10.31 |
| london_first120_reference | 26 | 2.40 | +0.4674 | +296.49 |
| newyork_first120_reference | 49 | 0.27 | -0.4356 | -517.74 |
| overlap_first120_reference | 32 | 0.86 | -0.0718 | -58.30 |
| target_multiple_1_2_reference | 25 | 1.26 | +0.1014 | +59.51 |
| target_multiple_2_0_reference | 22 | 0.98 | -0.0104 | -5.53 |

Checks:

- London reference now produced 26 trades, all at UTC hour 7 or 8 with `minutes_from_session_start` 0-105.
- Tokyo reference exported `tokyo=USDJPY|EURJPY|GBPJPY|AUDJPY` and traded only JPY pairs.
- HTF H4/H1 confirmed alignment reduced trade count below the 200-trade operating threshold.
- London is an interesting fragment, but it is not a fixed BT candidate because it has only 26 trades.

## Decision

Do not advance to 3-year fixed BT or OOS.

Reasons:

- No integrated scenario reached 200 trades with PF >= 1.05, avg_R > 0, and net > 0.
- The best expectancy fragments are too sparse to promote.
- New York remains structurally poor after HTF alignment.
- Clean target path still over-filters and does not create a deployable sample.
- No repair was attempted through symbol exclusion, direction exclusion, weekday stopping, or fine parameter tuning.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/session_candidate_map_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/retest_reference_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/htf_wave3_direction_breakdown.csv`

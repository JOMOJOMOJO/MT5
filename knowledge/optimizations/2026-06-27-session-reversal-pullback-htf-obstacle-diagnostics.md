# Session Reversal Pullback HTF Wave Alignment Diagnostics

## Hypothesis

Session reversal pullbacks may improve if:

- Tokyo, London, Overlap, and New York are evaluated as independent start windows instead of exclusive labels;
- Tokyo trades only JPY pairs;
- lower-timeframe M15/M5 reversal patterns are treated as wave3-start candidates only when H4 and H1 confirmed fractal wave3 direction agree;
- broken neckline/opening-range/session lines are treated as retest bases instead of forward obstacles.

## Prior Lessons Applied

- Confirmed wave3 breaks have been materially better than early unconfirmed wave3 entries in prior Elliott/fractal diagnostics.
- Neckline-break market entries tend to chase; retest/acceptance is a better first-pullback expression.
- Obstacle filters can easily become over-pruning filters, so clean-path scenarios remain diagnostic rather than a rescue mechanism.

## Tested Scenarios

- `session_reversal_pullback_all_symbols_first120`
- `session_reversal_pullback_one_symbol_first120`
- `session_reversal_pullback_one_symbol_first60`
- `session_reversal_pullback_clean_target_path_first120`
- `session_reversal_pullback_clean_target_path_first60`
- `tokyo_first120_reference`
- `london_first120_reference`
- `newyork_first120_reference`
- `overlap_first120_reference`
- `target_multiple_1_2_reference`
- `target_multiple_2_0_reference`

## Outcome

No 2025 shallow gate pass.

Main comparison:

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

## Lessons

- Non-exclusive session labeling fixed the London blind spot: London first120 now evaluates UTC 07:00-08:59 and produced 26 trades.
- Tokyo gating worked: Tokyo candidate map was `tokyo=USDJPY|EURJPY|GBPJPY|AUDJPY`, and only JPY pairs traded.
- H4/H1 confirmed wave3 alignment improved selectivity but cut the integrated sample below the 200-trade operating threshold.
- London first120 is the best fragment, but 26 trades is not enough for fixed BT or live consideration.
- New York remains a structurally bad bucket after HTF alignment.
- Broken neckline/opening/session levels as retest references are useful diagnostics, but they do not rescue the integrated system.

## Rejection Rule Applied

The family is not advanced because no integrated scenario had 200+ trades with PF >= 1.05, avg_R > 0, net > 0, and no DD stop. The sparse positive fragments are retained as research evidence only.

No post-hoc rescue was attempted through:

- symbol exclusion;
- direction exclusion;
- Friday or weekday stopping;
- fine fib/session/RSI/MACD threshold tuning;
- additional wave-count narrowing.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/r_metrics.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/session_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/retest_reference_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/session_candidate_map_breakdown.csv`

# FX Fractal Dow Elliott Session Diagnostics

## Scope

This cycle tested whether the failed Elliott roadmap family could become viable by adding:

- fractal alignment between H4/H1 pivots
- Dow regime labels
- session and volatility context
- symbol-best-session routing
- a wave3-confirmed variant

The EA was `ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader`, strategy tag `RESEARCH_STRATEGY_FX_FRACTAL_DOW_ELLIOTT_SESSION`.

## 2025 Shallow Gate

No primary scenario passed.

| Scenario | Trades | PF | avg_R | Net | DD stop | Decision |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| baseline_all_sessions | 339 | 0.65 | -0.1980 | -1502.75 | true | reject |
| session_volatility_only_filter | 268 | 0.62 | -0.2141 | -1309.22 | true | reject |
| symbol_best_session | 268 | 0.62 | -0.2141 | -1309.22 | true | reject |
| symbol_best_session_with_dow_alignment | 288 | 0.59 | -0.2329 | -1485.20 | true | reject |
| symbol_best_session_with_wave3_confirmed | 147 | 0.89 | -0.0428 | -165.82 | false | reject: trades < 200 and expectancy negative |

Reference-only session scenarios were not eligible for promotion. The overlap reference avoided DD stop but still had PF 0.61, avg_R -0.1892, and net -1019.79.

## Reusable Lessons

- The early wave3 problem remains the core failure. `wave3_unconfirmed_too_early` was the largest losing failure bucket across the main scenarios.
- Wave3 confirmation improves the loss profile in some cases, but the resulting candidate did not meet the 200-trade operating threshold and still had negative expectancy.
- Session filtering and symbol-best-session routing did not create edge; they mostly changed where the same negative expectancy appeared.
- Dow alignment did not improve the primary gate result in this run.
- Fractal/Dow/session diagnostics are useful labels, but they are not sufficient as hard gates for this family.

## Rejected Rescue Paths

Do not continue this family by:

- excluding specific symbols
- limiting to one direction
- adding a Friday stop
- finely optimizing Fib, RSI, MACD, session rank, or volatility thresholds
- adding more wave-count conditions to over-filter the same setup

## Evidence

- Summary: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/summary.md`
- Comparison: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/comparison.csv`
- Failure breakdown: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/failure_type_breakdown.csv`
- Wave3 comparison: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/wave3_break_confirmed_breakdown.csv`
- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader_compile.txt`

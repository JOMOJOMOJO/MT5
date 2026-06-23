# FX Fractal Dow Elliott Session Diagnostics

## Task

Implemented `ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader` as a multi-currency MT5 research EA for:

- `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- strategy tag `RESEARCH_STRATEGY_FX_FRACTAL_DOW_ELLIOTT_SESSION`
- Elliott roadmap labels from confirmed H1/H4 pivots
- fractal alignment, Dow regime labels, and session-volatility diagnostics
- 2025 shallow BT across baseline, session-filter, reference-session, symbol-best-session, Dow-aligned, and wave3-confirmed scenarios

## Implementation Notes

- H1/H4 pivots use confirmed closed bars only.
- `InpSwingDepth=3` requires 3 right-side closed bars before a pivot is usable.
- ZigZag repaint buffers are not used for entry decisions.
- Session labels use `InpBrokerUtcOffsetHours=2`; London/New York overlap is labeled before single-session buckets.
- CSV diagnostics include `session_label`, `session_window_name`, `session_volatility_rank`, `dow_regime_h4`, `dow_regime_h1`, `h4_structure`, `h1_structure`, `fractal_alignment`, volatility audit fields, `wave_stage`, `setup_type`, `failure_type`, `result_r`, `wave3_break_confirmed`, and pivot delay columns.

## Evidence

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader_compile.txt`
- Main diagnostics: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/summary.md`
- Comparison CSV: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/comparison.csv`
- All-trades CSV: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/trades_all_scenarios.csv`
- Session audit: `reports/backtest/runs/20260624_fxfractal_dow_elliott_session_diagnostics/session_volatility_audit.csv`
- MT5 reports and tester INIs: `reports/backtest/ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader_*_2025*`
- Presets: `reports/presets/ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader_*_2025.set`

## Result

Compile passed with `0 errors, 0 warnings`.

No primary 2025 shallow scenario passed the promotion gate:

- `baseline_all_sessions`: 339 trades, PF 0.65, avg_R -0.1980, net -1502.75, DD stop true.
- `session_volatility_only_filter`: 268 trades, PF 0.62, avg_R -0.2141, net -1309.22, DD stop true.
- `symbol_best_session`: 268 trades, PF 0.62, avg_R -0.2141, net -1309.22, DD stop true.
- `symbol_best_session_with_dow_alignment`: 288 trades, PF 0.59, avg_R -0.2329, net -1485.20, DD stop true.
- `symbol_best_session_with_wave3_confirmed`: 147 trades, PF 0.89, avg_R -0.0428, net -165.82, DD stop false, but trade count was below 200 and expectancy stayed negative.

The largest losing failure bucket was `wave3_unconfirmed_too_early`. In `baseline_all_sessions`, `wave3_break_confirmed=false` had 250 trades, avg_R -0.2925, and PF_from_trades 0.54, while `true` had 89 trades, avg_R 0.0673, and PF_from_trades 1.19.

## Decision

Do not promote this EA to 3-year fixed BT or latest 12-month OOS. Do not rescue the failed 2025 shallow result by excluding symbols, limiting direction, stopping Friday trades, or fine-tuning Fib/RSI/MACD/session thresholds.

The reusable finding is that adding fractal alignment, Dow labels, and session-volatility filters did not fix the structural weakness of early wave3 entries. Wave3 confirmation improved expectancy in some scenarios, but it reduced trade count below the operating threshold and still did not produce a deployable basket candidate.

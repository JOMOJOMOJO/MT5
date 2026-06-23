# FX Elliott Wave Roadmap Diagnostics

## Task

Implemented `ExpectedValue_MultiCurrency_FXElliottWaveRoadmapTrader` as a multi-currency MT5 EA for:

- `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- H1/H4 confirmed pivot roadmap labels, not strict Elliott counting
- diagnostic setup modes for wave3 start, wave4 continuation, ABC completion, and combined triggers
- structure-first SL and `InpRewardR=1.40`
- risk guards for spread, duplicate entries, per-symbol risk, total open risk, daily loss, and portfolio drawdown

## Implementation Notes

- Confirmed pivots are detected from closed H1/H4 bars only.
- `InpSwingDepth=3` requires 3 right-side closed bars before a pivot is usable.
- No repaint ZigZag value is used for entry decisions.
- CSV diagnostics include `pivot_confirmation_delay_bars`, `entry_delay_from_pivot`, `pivot_time`, `pivot_confirmed_time`, `wave_stage`, `setup_type`, `fib_zone`, `divergence_type`, `m15_confirmation_type`, `failure_type`, `room_to_2r`, and `wave3_break_confirmed`.
- `possible_wave5_exhaustion` is logged as a combined-mode diagnostic signal only. It is not traded as a fixed candidate.

## Evidence

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_FXElliottWaveRoadmapTrader_compile.txt`
- Main diagnostics: `reports/backtest/runs/20260623_fxelliott_roadmap_diagnostics/summary.md`
- Comparison CSV: `reports/backtest/runs/20260623_fxelliott_roadmap_diagnostics/comparison.csv`
- Combined run artifacts: `reports/backtest/runs/20260623_fxelliott_combined_2025/`
- Single setup run artifacts:
  - `reports/backtest/runs/20260623_fxelliott_wave3_start_pullback_2025/`
  - `reports/backtest/runs/20260623_fxelliott_wave4_continuation_2025/`
  - `reports/backtest/runs/20260623_fxelliott_abc_completion_reentry_2025/`

## Result

All 2025 shallow tests failed. The combined candidate had 551 closed trades, PF 0.72, avg_R -0.1125, net -1412.68, and drawdown stop triggered.

The best diagnostic component was combined `abc_completion_reentry`, but it still had avg_R -0.0161 and PF_from_trades 0.93 over 123 trades. It is not a fixed BT or live candidate.

Key failure signatures:

- `wave3_break_confirmed=false` was materially worse than confirmed wave3 starts.
- `wave4_continuation` behaved like a chase setup, not a continuation edge.
- ABC completion was least bad but did not produce positive expectancy.
- Fib confluence and divergence did not justify hard gates in this run.

## Decision

Do not promote this EA to 3-year fixed BT or latest 12-month OOS. Do not attempt to rescue the failed 2025 shallow result by excluding symbols, limiting direction, stopping Friday trades, or fine-tuning RSI/MACD/Fib thresholds.

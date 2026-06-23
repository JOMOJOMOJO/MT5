# FX Elliott Wave Roadmap Diagnostics

## Hypothesis

An Elliott-wave-inspired roadmap might create positive expectancy if H1/H4 confirmed swing structure is combined with M15 reversal confirmation across a six-symbol FX basket.

The test intentionally avoided strict wave counting and treated the setup labels as diagnostics:

- `possible_wave3_start`
- `possible_wave4_pullback`
- `possible_abc_completion`
- `possible_wave5_exhaustion`

## Validation

Backtested 2025 shallow scenarios on MT5 M15, Model=4, Deposit=10000:

- `wave3_start_pullback_only`
- `wave4_continuation_only`
- `abc_completion_reentry_only`
- `combined_roadmap_triggers`

Artifacts are under `reports/backtest/runs/20260623_fxelliott_roadmap_diagnostics/`.

## Findings

- No 2025 shallow candidate passed.
- Combined result: 551 trades, PF 0.72, avg_R -0.1125, net -1412.68, drawdown stop true.
- Single setup results were also negative despite adequate trade count:
  - wave3 start: 446 trades, PF 0.71, avg_R -0.1283
  - wave4 continuation: 356 trades, PF 0.66, avg_R -0.1646
  - ABC completion: 601 trades, PF 0.76, avg_R -0.0963
- In combined mode, ABC completion was least bad but still negative: 123 trades, avg_R -0.0161.
- `wave3_break_confirmed=false` was much worse than confirmed starts, so early wave3 entries were too early.
- `wave4_continuation` showed chase risk, especially when divergence opposed continuation.
- `possible_wave5_exhaustion` diagnostics were recorded, but this did not rescue the roadmap because the traded setup population was already negative.

## Rejected Repairs

Per the plan, this failure should not be extended by:

- excluding specific symbols
- limiting to one direction
- adding Friday stops
- narrowly tuning Fib thresholds
- narrowly tuning RSI/MACD thresholds
- adding more wave-count filters to overfit the sample

## Decision

Park this Elliott roadmap candidate as not deployable. If revisited, it should start as fresh edge research on swing-regime statistics, not as incremental retuning of this EA.

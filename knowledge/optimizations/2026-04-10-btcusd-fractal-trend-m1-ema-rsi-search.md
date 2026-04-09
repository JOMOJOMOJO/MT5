# BTCUSD Fractal Trend M1: EMA / RR / RSI Search

- Date: `2026-04-10`
- EA:
  - `mql/Experts/btcusd_20260409_fractal_trend_research.mq5`
- Goal:
  - validate whether the old `Fractal + EMA + momentum` trend-follow branch can survive as a standalone `BTCUSD / M1` operating candidate before any `M3/M5` parallelization is attempted.

## Baseline

- Preset:
  - `reports/presets/btcusd_20260409_fractal_trend_research-m1-baseline.set`
- Long-window actual:
  - `2025-04-01` to `2025-12-31`
  - `net -29.95`
  - `PF 0.00`
  - `1 trade`
  - `balance DD 0.30%`
- Recent OOS:
  - `2026-01-01` to `2026-04-01`
  - `net 0.00`
  - `PF 0.00`
  - `0 trades`
  - `balance DD 0.00%`

## Search 1: EMA / RR / RSI Period

- Search preset:
  - `reports/presets/btcusd_20260409_fractal_trend_research-m1-search.set`
- Search window:
  - `2025-10-01` to `2025-11-30`
- Dimensions:
  - `Fast EMA`
  - `Mid EMA`
  - `Slow EMA`
  - `RiskReward`
  - `RSI period`
- Result:
  - the search found only sparse winners.
  - best positive cluster centered around:
    - `Fast 12`
    - `Mid 60`
    - `Slow 150`
    - `RSI period 24`
    - `RR 1.4`
- Best search row:
  - `profit +14.25`
  - `PF 1.55`
  - `2 trades`
  - `DD 0.29%`
- Interpretation:
  - the issue was not just the exact EMA stack.
  - even the best parameter area stayed too sparse for promotion.

## Search 2: RSI Threshold Probe

- Search preset:
  - `reports/presets/btcusd_20260409_fractal_trend_research-m1-rsi-probe.set`
- Fixed core:
  - `Fast 12`
  - `Mid 60`
  - `Slow 150`
  - `RSI period 24`
  - `RR 1.4`
- Search window:
  - `2025-10-01` to `2025-11-30`
- Dimensions:
  - `Long RSI min`
  - `Short RSI max`
- Best rows:
  - `Long RSI min 60`
  - `Short RSI max 42-50` all equivalent
  - `profit +115.12`
  - `PF 2.38`
  - `8 trades`
  - `DD 0.52%`
- Interpretation:
  - `Long RSI min` was the true bottleneck.
  - `Short RSI max` had no effect in the search window, which means the provisional edge was effectively long-only.

## Validation Candidate

- Candidate preset:
  - `reports/presets/btcusd_20260409_fractal_trend_research-m1-long60.set`
- Candidate shape:
  - `BTCUSD / M1`
  - `long-only`
  - `EMA 12 / 60 / 150`
  - `RSI period 24`
  - `Long RSI min 60`
  - `RR 1.4`
  - stop anchored to `EMA60` or `EMA150` depending on pullback depth

## Candidate Validation

- Long-window actual:
  - `2025-04-01` to `2025-12-31`
  - `net -176.09`
  - `PF 0.63`
  - `25 trades`
  - `balance DD 2.13%`
- Recent OOS:
  - `2026-01-01` to `2026-04-01`
  - `net -29.78`
  - `PF 0.73`
  - `6 trades`
  - `balance DD 0.78%`

## Verdict

- Reject `BTCUSD / M1` as an operating candidate for this method in its current form.
- Do not parallelize `M3` or `M5` until one timeframe first proves positive expectancy over:
  - `9 months train`
  - `3 months OOS`
- Reusable lesson:
  - short-window wins were created by threshold relaxation,
  - but the underlying `M1` trend-follow edge remained too weak and too sparse on long validation.

# 2026-04-01 BTCUSD Feature Lab Mainline Hypotheses

- Source artifact:
  - `reports/research/2026-04-01-142232-btcusd-m5-feature-lab/summary.md`
  - `reports/research/2026-04-01-142232-btcusd-m5-feature-lab/summary.json`
  - `reports/research/2026-04-01-142232-btcusd-m5-feature-lab/analysis_window_features.csv.gz`
- Objective:
  - open a higher-turnover mainline family from chart behavior instead of stretching the parked `session_meanrev`
  - keep the latest `9 months train / 3 months OOS` split discipline

## Data Window

- MT5 history available in this run:
  - `2025-04-16 12:25` -> `2026-04-01 08:25`
- This is slightly shorter than a full `365-day` window because the broker-side M5 history appears capped below a full year.
- The process should keep using the latest available history unless a deeper external feed is added deliberately.

## What The Data Says

- The strongest stable single-feature relationships are weak in raw correlation but consistent in sign:
  - `roc_atr_6`, `high_break_12`, `rsi7`, `bb_z`, `stoch_k`, and `close_vs_ema20`
- The dominant structure is short-horizon overextension mean reversion:
  - stretched downside tends to bounce
  - stretched upside tends to fade
- A second structure also appears:
  - high range compression supports a later long breakout continuation on the `12-bar` horizon

## Mainline Hypothesis A: Overextension Fade

- This is the preferred next family because both sides survive OOS and turnover is high enough to matter.

### Long Side Candidate

- strongest pair:
  - `roc_atr_6 <= -1.3739`
  - `ret_6 <= -0.0016`
  - horizon `3` or `6`
- alternative long pair:
  - `roc_atr_6 <= -1.3739`
  - `rsi7 <= 29.5772`
  - horizon `3` or `6`

### Short Side Candidate

- strongest pair:
  - `rsi7 >= 70.3688`
  - `ret_6 >= 0.0017`
  - horizon `6`
- alternative short pair:
  - `rsi7 >= 70.3688`
  - `high_break_12 >= -0.5770`
  - horizon `6`

### Why It Looks Promising

- test trades/day remains high after the pair filter:
  - long pair examples: roughly `39` to `51` trades/day
  - short pair examples: roughly `32` to `42` trades/day
- test hit rates are usually around `55%`
- test expectancy remains positive on both sides

## Secondary Hypothesis B: Compression Breakout Long

- pair:
  - `range_compression_12 >= 0.0075`
  - `range_compression_24 >= 0.0108`
  - horizon `12`
- this looks useful, but it is not the first prototype because:
  - it is one-sided,
  - it is less symmetric,
  - and the overextension-fade branch has a clearer two-sided family structure

## Decision

- Open the next mainline prototype from `Overextension Fade`.
- Do not return to broad optimization until this pair-rule thesis has been turned into an actual MT5 EA and judged on actual MT5 results.
- Keep `Compression Breakout Long` as a secondary research branch.

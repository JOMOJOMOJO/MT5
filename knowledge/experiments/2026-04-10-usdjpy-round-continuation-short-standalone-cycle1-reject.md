# USDJPY round continuation short standalone cycle 1 reject

- Date: `2026-04-10`
- Family: `usdjpy_20260410_round_continuation_short_guarded`
- Goal:
  - test whether Method 1's `M15 round continuation` idea can survive as a standalone `short-only` branch before any coexistence work with `quality12b_guarded`

## What Was Built

- EA:
  - `mql/Experts/usdjpy_20260410_round_continuation_short_guarded.mq5`
- Thesis:
  - `LL / LH` structure on `USDJPY / M15`
  - `EMA13 < EMA100`
  - negative `EMA100` slope
  - 50-pip anti-chop volatility state
  - bullish pullback signal bar near `EMA13`
  - structure-aware stop above the signal high plus buffer
  - fixed `R` target and time stop
- Compile:
  - MetaEditor log reports `0 errors, 0 warnings`

## Tested Presets

### `baseline`

- Train `2025-04-01` to `2025-12-31`:
  - `net +32.16`
  - `PF 1.41`
  - `4 trades`
  - `max balance DD 0.39%`
- OOS `2026-01-01` to `2026-04-01`:
  - `net -39.26`
  - `PF 0.00`
  - `1 trade`
  - `max balance DD 0.39%`

### `strict`

- Train:
  - `net +0.00`
  - `PF 0.00`
  - `0 trades`
- Verdict:
  - too restrictive to matter

### `carry`

- Train:
  - `net +126.21`
  - `PF 1.80`
  - `10 trades`
  - `max balance DD 0.78%`
- OOS:
  - `net -39.00`
  - `PF 0.00`
  - `1 trade`
  - `max balance DD 0.39%`

### `guarded`

- Train:
  - `net +51.29`
  - `1 trade`
  - `max balance DD 0.00%`
- OOS:
  - `net -39.64`
  - `PF 0.00`
  - `1 trade`
  - `max balance DD 0.40%`

### `quick`

- Train:
  - `net +38.94`
  - `1 trade`
  - `max balance DD 0.00%`
- OOS:
  - `net -39.64`
  - `PF 0.00`
  - `1 trade`
  - `max balance DD 0.40%`

## Verdict

- Reject the standalone mirrored `round continuation short` as an operational candidate.
- The best train shape came from `carry`, but it still failed the latest `3 months OOS` with a single losing trade.
- The stricter variants reduce damage only by collapsing sample size.
- This does not clear the repo gate for `demo-forward candidate`:
  - train sample is too thin,
  - latest OOS is negative,
  - no preset achieved positive latest OOS with informative trade count.

## Why It Failed

- The short side is not simply the long side turned upside down on this `USDJPY` feed.
- The surviving signals cluster into a very sparse bearish-pullback neighborhood, and the latest executable window did not confirm that edge.
- Tightening the filters improves apparent train quality only by starving the sample.
- Loosening them increases train turnover, but the latest OOS still falls back to the same single losing setup.

## Routing Decision

- Keep `quality12b_guarded` as Method 1 and the only operational mainline.
- Do not combine this mirrored short branch with Method 1.
- If a short-side Method 3 is reopened later, it should be a fresh family:
  - not another mirrored `round continuation short`
  - not a looser variant of the same bearish pullback geometry

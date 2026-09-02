# Step 15J pre-analysis: post-shock excursion and geometry

## Scope and frozen question

This is a March 2025 development study. It records the executable Bid/Ask path after the existing `TAIL_V1_PERSISTENT` confirmation and asks how far and how quickly price travels before any TP/SL choice is imposed. It does not change detector thresholds, episode rules, strategies, RR, stop grid, watermark semantics, or order behavior. No production entry rule is created.

## Population and clocks

- Statistical detector time: the existing candidate timestamp.
- Persistent confirmation time: the existing confirmed grid timestamp.
- EA decision-available time: the existing `processing_msc` supplied when confirmation is recognized.
- Primary `t0`: EA decision-available time.
- Entry/reference quote: the first valid, non-fallback real quote for the same symbol with `quote_msc > confirmed_quote_msc` and `quote_msc >= t0`.
- Episode population: the unchanged Step 15E persistent episodes. Same-symbol repeats during an active episode remain annotations; they do not create new episodes.
- A path is 60-minute complete only when a valid quote at or after `t0 + 3600s` is observed. End-of-data censored paths remain explicit and are excluded from complete-path estimates.

## Fixed horizons and distances

Horizon seconds are fixed before observing outcomes: `30, 60, 120, 300, 600, 900, 1800, 3600`.

ATR-normalized first-hit distances are fixed before observing outcomes: `0.10, 0.20, 0.30, 0.40, 0.50, 0.75, 1.00, 1.50`.

TP diagnostic candidates are limited to the coarse preregistered set `0.20, 0.30, 0.40, 0.50 ATR`. They are reported as ranges and are not optimized. SL diagnostics use the pre-TP MAE distribution for episodes that reach each candidate TP. RR is derived only after TP and SL ranges are described.

## Excursion oracle

ATR is M5 ATR14 computed only from completed bars available at `t0`. It is frozen for the episode.

For a continuation long, entry is Ask and liquidation is Bid; for a continuation short, entry is Bid and liquidation is Ask. Reversal uses the opposite direction. At each quote, signed executable move is `(liquidation_side - entry_price) * direction`; cumulative MFE is the maximum positive move and cumulative MAE the maximum negative move in absolute units. Each horizon captures the cumulative state at the first quote at or after its target.

First-hit time is measured from the entry/reference quote. Pre-TP MAE is the greatest adverse executable excursion strictly before or on the first quote that reaches the candidate favorable distance. Same-millisecond quotes are processed in source sequence and the existing grouped quote semantics are retained.

## Existing geometry audit

At the entry/reference quote, the unchanged Step 15G geometry is reconstructed through the production geometry function:

`SL distance = max(0.25 * completed M5 ATR14, 4 * entry spread, broker minimum distance)`

`TP distance = 1.2 * rounded SL distance`

The dominant component is reported as `ATR`, `SPREAD`, or `BROKER_MIN`, including exact ties according to the production precedence. Geometry is diagnostic only.

## Causal high-movement population

The Step 15I +60-second values are prohibited at `t0`. The recorder stores only t0-causal completed-bar ATR, entry spread/ATR, and the detector's contemporaneous tick-activity ratio. Offline selection uses the frozen Step 15I rule independently per symbol: spread/ATR at or below the past-only 30th percentile, tick activity at or above the past-only 70th percentile, and ATR at or above the past-only 70th percentile, requiring 100 strictly earlier eligible episodes. The current and future rows never enter their thresholds. If those fields cannot be reconstructed causally, the report must state `T0_HIGH_MOVEMENT_FILTER_NOT_AVAILABLE` and use the all-episode population only.

## Holding-time interpretation

For each horizon, report median/P75/P90 MFE/ATR, its increment from the prior horizon, its fraction of the 60-minute MFE, and corresponding MAE growth. A reasonable holding range may be described only as a coarse registered horizon band; no second-level optimum is selected.

## Independence and QA

The independent Python oracle reads the research CSV and recomputes funnel counts, symbol counts, horizon excursions, first-hit counts, pre-TP MAE, and existing geometry dominance without calling MQL functions. Required invariants are: no future feature source, no pre-t0 entry quote, no duplicate episode ID, no invalid Bid/Ask path, no future ATR or percentile, no market-cluster integrity failure, and zero orders/trades.

## Decision boundary

This development sample can support or reject geometry plausibility only. It cannot establish strategy edge or authorize production. Required terminal vocabulary includes `PARAMETER_FREEZE_NOT_READY`, `OOS_VALIDATION_REQUIRED`, and `PRODUCTION_NOT_ELIGIBLE` unless a later, separately preregistered OOS gate is completed.

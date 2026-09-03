# Step 15K pre-analysis: tradeable move and cross-symbol normalization

## Scope

This is a March 2025 development study. It asks whether the unchanged persistent-shock population contains a material subset that reaches a coarse ATR-normalized target quickly and with limited adverse excursion. It does not change the detector, episode construction, four strategy definitions, global watermark, RR, stop grid, order behavior, or any production entry rule.

## Causal clock and executable path

- Statistical time, persistent-confirmation time, processing time, and primary `t0` retain their Step 15J meanings.
- Primary `t0` is the first processing timestamp at which the EA can causally recognize persistent confirmation.
- Entry/reference is the first valid same-symbol real quote at or after `t0` and strictly after the confirmation quote.
- Long uses Ask entry and Bid liquidation; short uses Bid entry and Ask liquidation.
- Completed M5 ATR14 available at `t0` is frozen as the price-distance denominator.
- Future price, ATR, percentile, spread, or tick activity may not enter a t0 feature.

## Horizon snapshot correction

For every registered horizon, the recorder stores target timestamp, actual snapshot quote timestamp, and `snapshot_lag_ms`. The first quote at or after the target may close the horizon only when lag is at most 30,000 ms, fixed before inspecting Step 15K outcomes. A larger lag produces `CENSORED_HORIZON_LAG`; it is not included in that horizon or later complete-path inference. End-of-data remains separately censored. The quote that closes a permitted horizon remains the first causal quote at or after its target.

## Relative-state normalization

Price distance uses absolute `ATR_t0`; volatility state uses a different construct: the position of `ATR_t0` within strictly earlier, same-symbol eligible episodes. Spread/ATR and tick activity are handled the same way. For each feature the dataset stores raw value, history count, past-only empirical percentile rank, and readiness reason.

The empirical rank is `(# past values below x + 0.5 * # past values equal to x) / history_count`. At least 100 strictly earlier valid same-symbol rows are required for each feature. Current and future rows never enter their own reference distribution. The frozen Step 15I high-movement selection remains based on past-only linear q30 spread/ATR, q70 tick activity, and q70 ATR thresholds so that Step 15J selection is reproducible; empirical ranks are additional cross-symbol diagnostics, not substituted cutoffs.

Readiness reasons are `READY`, `INSUFFICIENT_SPREAD_HISTORY`, `INSUFFICIENT_ACTIVITY_HISTORY`, `INSUFFICIENT_ATR_HISTORY`, `INVALID_SPREAD_ATR`, `INVALID_TICK_ACTIVITY`, `INVALID_ATR`, and `EXCLUDED_TICK_QUALITY`. The primary funnel is analysis-ready -> relative-state-ready -> high-movement selected. GBPUSD remains visible but excluded from formal normalized inference because its March tick provenance is unresolved.

## Frozen tradeable-move matrix

The primary matrix is the Cartesian product of:

- TP: 0.30, 0.40, 0.50 ATR;
- maximum holding: 600, 900, 1,800 seconds;
- maximum pre-TP MAE: 0.15, 0.20, 0.25, 0.30, 0.40 ATR.

This gives 45 equally registered geometries. No best cell is selected. Five- and 60-minute results are reported only as holding diagnostics. The previously registered 0.20, 0.75, and 1.00 ATR distances remain diagnostics and do not expand the primary matrix.

For each direction and geometry:

- `CLEAN_CONTINUATION` or `CLEAN_REVERSAL`: target first hit occurs within the maximum holding time and pre-target MAE does not exceed the registered limit;
- `NOISY_MOVE`: the target is reached within the valid 60-minute path but only after the holding limit or after exceeding the MAE limit;
- `INSUFFICIENT_MOVE`: neither side reaches the target within the valid 60-minute path;
- `BOTH_CLEAN`: both directions meet the clean definition; first completion timestamp determines the recorded priority, with same-timestamp ties explicit.

`RR_feasible = TP_ATR / MAE_LIMIT_ATR` is a path-feasibility descriptor, not an instruction to set SL. The report groups cells by RR >= 1.0, 1.2, 1.5, and 2.0. Any cell with fewer than 20 market clusters is `INSUFFICIENT_SUPPORT` and cannot support an edge claim.

## Comparisons

The high-movement population is compared with relative-ready unselected rows using clean continuation, clean reversal, either-clean, noisy, insufficient, time-to-target, and pre-target MAE. Cluster bootstrap intervals use market clusters as resampling units with a fixed seed and 2,000 draws. Symbol and session tables are mandatory; an aggregate result cannot override contradictory symbol evidence.

Existing causal features from Steps 15F-15I are compared for clean versus noisy, clean continuation versus all others, clean reversal versus all others, and clean continuation versus clean reversal. Bins are coarse past-only percentile or frozen categorical bins. These comparisons are descriptive feature discovery. Optional simple models are permitted only with adequate samples and time-ordered, cluster-aware splits; a failed or uninformative model is reported rather than tuned.

## QA and decision boundary

Required checks are compile 0/0, deterministic regression, production-path harness, zero pre-t0 entry, zero future feature use, zero duplicate episode ID, valid Bid/Ask paths, explicit horizon-lag censoring, market-cluster integrity, and zero orders/trades. An independent Python oracle must recompute the funnel, relative readiness, empirical percentiles, labels, holding counts, high-movement comparison, and headline symbol counts without importing production formulas.

This repeatedly used March sample can establish only whether a tradeable-move population exists and whether causal state features appear useful. It cannot establish expectancy or production eligibility. `PARAMETER_FREEZE_NOT_READY`, `OOS_VALIDATION_REQUIRED`, and `PRODUCTION_NOT_ELIGIBLE` remain mandatory unless a later preregistered unused-period test passes.

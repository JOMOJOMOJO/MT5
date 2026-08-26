# Tick-shock statistical detector V1 - frozen specification

This is the concise implementation contract fixed before any Step 15A V1
development result is viewed. Rationale and literature boundaries are in
`15a_shock_redefinition_preanalysis.md`.

## Versioned identifiers

| Item | Value |
|---|---|
| legacy detector | `STRICT_V0` |
| V1 raw | `TAIL_V1_RAW` |
| V1 noise robust | `TAIL_V1_NOISE_ROBUST` |
| V1 persistent | `TAIL_V1_PERSISTENT` |
| feature schema | `tickshock-detector-feature-v1` |
| selector default | `STRICT_V0` |
| decision grid | 250 ms |
| horizons | 250, 500, 1,000 ms |

## Canonical algorithm

1. Close each 250 ms grid boundary after the final same-millisecond quote.
2. Reject the boundary if Bid/Ask, exact anchors, quote age, cursor, frontier,
   or numeric integrity is invalid.
3. Compute raw Mid. For robust estimators compute
   `(M_t + 2*M_t-250 + M_t-500)/4`; do not backdate its timestamp.
4. Compute exact log return for each horizon.
5. Build the 15-minute same-horizon local-scale pool ending at `t-2000`.
6. Require at least 300 signed returns. Compute
   `BV=(pi/2)*mean(|r_j|*|r_j-1|)` and
   `sigma=max(sqrt(BV),tick_size/reference_mid)`.
7. Compute `score=abs(r)/sigma` and key calibration by symbol, horizon,
   estimator, server-time four-hour bucket, and volatility regime
   (`sigma/noise`: LOW `<2`, NORMAL `[2,5)`, HIGH `>=5`).
8. Add a historical score to calibration only when its timestamp is at least
   2,000 ms behind the current boundary.
9. Use a 0.01-wide bounded score histogram over `[0,50]`; equal bin counts as
   an exceedance. `p=(1+exceedances)/(N+1)`.
10. Require `N>=10000`. Require `N>=50000` before labeling 99.9 severity.
11. Apply Holm adjustment across ready horizons. A V1 statistical candidate
    exists when any adjusted p is at most 0.01. Record nested 99.0, 99.5, and
    99.9 bands at adjusted p 0.01, 0.005, and 0.001.
12. Deduplicate simultaneous horizons into one symbol/boundary candidate.
    Trigger horizon is minimum adjusted p; ties choose shorter horizon.
13. RAW and NOISE_ROBUST confirm immediately at the candidate boundary.
14. PERSISTENT confirms only at the next 250 ms boundary when the robust price
    retains at least 50% of the candidate move in its direction. It expires
    otherwise. Signal time equals confirmation time.
15. Pass accepted events to the unchanged burst/state/scenario production
    path. Never use strategy P/L to alter this algorithm.

## Exact constants

```text
grid_ms                         = 250
horizons_ms                     = 250|500|1000
max_quote_age_ms                = 500
baseline_minutes                = 15
baseline_exclude_ms             = 2000
min_local_scale_samples         = 300
noise_floor_ticks               = 1.0
tod_bucket_hours                = 4
vol_regime_ratio_low_upper      = 2.0
vol_regime_ratio_normal_upper   = 5.0
score_bin_width                 = 0.01
score_bin_max                   = 50.0
min_calibration_samples         = 10000
min_999_calibration_samples     = 50000
event_alpha_fwer                = 0.01
severity_990_alpha              = 0.01
severity_995_alpha              = 0.005
severity_999_alpha              = 0.001
persistence_confirmation_ms     = 250
persistence_retained_fraction   = 0.50
symbol_cluster_ms               = 2000
market_cluster_ms               = 2000
bootstrap_replicates            = 10000
bootstrap_mean_block_clusters   = 4
bootstrap_seed                  = 20260826
primary_adjustment              = HOLM_FWER
secondary_adjustment            = BH_FDR_0.05
```

## Output contract

Existing event/summary columns retain their meanings. A versioned detector
feature record adds: detector ID, specification hash, candidate/confirmed time,
trigger horizon, horizon masks, raw/adjusted p, empirical percentile, severity,
local score/scale, baseline/calibration counts, Wilson half-width, time bucket,
volatility regime, noise estimate, efficiency, intensity, move/spread, spread
ratio, quote age, and the six separated statuses `statistical_shock`,
`directional_burst`, `activity_elevated`, `liquidity_normal`, `cost_feasible`,
and `strategy_signal`.

## Fail-closed contract

Missing exact anchor, future input, insufficient local or calibration sample,
stale/invalid quote, invalid denominator, non-finite value, histogram/capacity
loss, duplicate event, cursor regression, or provenance mismatch cannot be
converted to a statistical event. It must increment a distinct diagnostic and
leave formal analysis ineligible when data integrity is affected.


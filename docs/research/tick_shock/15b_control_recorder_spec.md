# Step 15B bounded control recorder specification

This document is normative for the Step 15B recorder and matching tests. The
detector specification and hash remain unchanged.

## Schema contracts

`tickshock-detector-feature-v2` appends a dedicated `direction` field without
deleting or redefining a v1 column. Allowed values are `LONG`, `SHORT`, and
`INVALID`. The schema contract fails if the column is absent.

`tickshock-control-candidate-v1` contains:

```text
control_candidate_id,detector_id,boundary_time_msc,symbol,time_bucket,
trigger_horizon_ms,estimator,volatility_regime,raw_p,adjusted_p,local_volatility,
direction,signed_return,spread,tick_activity,quote_age_ms,data_integrity_status,
complete_120s,shock_excluded,unmatched_reason,source_commit,spec_sha256,
schema_id,abs_return_1s,abs_return_3s,abs_return_10s,abs_return_30s,
abs_return_120s,realized_volatility_120s,mfe_120s,mae_120s,
spread_change_120s,tick_activity_120s,quote_reversion_ratio,
cluster_duration_comparison_ms,fallback_trigger_overlap,
fallback_baseline_overlap,fallback_confirmation_overlap,fallback_outcome_overlap,
record_status
```

The recorder is memory-bounded. It never writes all ticks or all boundaries.
Only mature controls selected by an event, terminal incomplete records needed
for reconciliation, and bounded integrity counters are serialized.

## Direction and horizon

The trigger horizon is the ready horizon with minimum adjusted p. Ties choose
250 before 500 before 1,000 ms. Direction comes from that horizon's signed
candidate-time return. PERSISTENT preserves it through confirmation. Zero,
NaN, infinity or missing return yields `INVALID`.

## Eligibility and maturity

A boundary is armed only from information available at that boundary. It
becomes mature only when all 1/3/10/30/120-second observations exist and all
intermediate values needed for 120-second RV/MFE/MAE are integrity-valid.
Research maturity cannot alter any signal clock or production state.

The exact match key and eligibility rules are those in
`15b_control_funnel_preanalysis.md`. Reuse is allowed and reported. A missing
key is `UNMATCHED_EXACT_KEY`; an unavailable complete earlier record is
`UNMATCHED_NO_COMPLETE_PRIOR`; shock proximity is
`UNMATCHED_SHOCK_EXCLUSION`; integrity loss is `UNMATCHED_INTEGRITY`.

## Fail-closed invariants

- candidate IDs are unique;
- one same-ms boundary is finalized once with its last quote;
- active capacity is 512 per symbol;
- capacity hit, drop, unexplained eviction or duplicate ID increments a named
  counter and sets validation invalid;
- period-end incomplete rows are not eligible;
- matching never relaxes a key or the 120,000-ms exclusion;
- future outcome values are write-only research evidence and cannot enter
  direction, detector or strategy decisions.


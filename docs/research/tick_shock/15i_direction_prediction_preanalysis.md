# Step 15I pre-analysis: direction prediction after a high-movement filter

## Frozen research question

Can causal information available at the registered Step 15G `+60s` decision checkpoint distinguish continuation from reversal after first selecting episodes likely to make a large post-shock move?

This is a reused March 2025 development study. It is feature discovery, not OOS validation, strategy selection, or production eligibility.

## Frozen population and outcome

- Source population: `TAIL_V1_PERSISTENT` shock episodes from the formal Step 15G run.
- Primary decision checkpoint: `decision_seconds=60`.
- Primary horizon: `horizon_seconds=900` from the shock anchor.
- Primary barrier geometry: Step 15G `requested_rr=1.2`, causal Bid/Ask first-touch rules, unchanged risk floor and cost definitions.
- Analysis eligibility: both CONTINUATION and REVERSAL primary paths are valid and the causal decision feature row is available.
- Direction label: the action whose TP is reached first is `CONTINUATION` or `REVERSAL`; neither TP is `NEUTRAL_TIMEOUT`. Equal first-touch millisecond is `AMBIGUOUS_SAME_MSC` and is excluded from directional fitting, not guessed.
- Independent sample unit: `market_cluster_id`; episode rows remain descriptive observations.

## Frozen high-movement filter

No prior fixed trading thresholds exist for the three variables. Thresholds will therefore be derived mechanically and causally, without searching for profit-maximizing cutoffs:

- low `spread_atr`: at or below the expanding, within-symbol 30th percentile;
- high `tick_activity`: at or above the expanding, within-symbol 70th percentile;
- high `ATR`: Step 15G `F17 atr14_m5`, at or above the expanding, within-symbol 70th percentile (the same completed-M5 ATR family used by the registered risk geometry);
- only observations with at least 100 strictly earlier eligible episodes for the same symbol receive a filter decision.

Thresholds use only rows with an earlier decision timestamp. The current row and future rows are excluded. Ties are retained. The filter is the conjunction of the three frozen predicates. No alternate quantile is selected after outcomes are observed.

## Frozen analyses

1. Population funnel and exclusions from detector rows through episodes, eligible paths, causal quantile readiness, and high-movement selection.
2. High-movement validation versus the ready but unselected population using MFE, MAE, absolute excursion/ATR, barrier-touch frequency, cluster bootstrap confidence intervals, and standardized/rank effects.
3. Direction label counts and continuation-versus-reversal feature comparisons with Neutral kept separate.
4. Five coarse past-only percentile bins for causal numeric features; bins with fewer than 20 market clusters cannot support an edge claim.
5. Four simple, ex-ante direction hypotheses only; no exhaustive AND search:
   - `M15_ALIGNMENT`: F09 `shock_alignment_m15` predicts continuation at +1 and reversal at -1;
   - `PRE_MOMENTUM_5M`: F13 `shock_pre_momentum_5m` predicts continuation above zero and reversal below zero;
   - `DIRECTIONAL_RANGE_POSITION`: direction-normalized F15 predicts continuation in the upper quintile and reversal in the lower quintile, using the same past-only percentile process;
   - `M15_AND_PRE_MOMENTUM`: require F09 and the sign of F13 to agree; otherwise abstain.
   None can support an edge claim with fewer than 20 selected market clusters.
6. Optional lightweight time-ordered model only as a signal-existence diagnostic, never as the primary result.

## Leakage and interpretation rules

- Feature source timestamps must not exceed the decision timestamp.
- Outcome fields, post-decision extrema, touch times, and full-period quantiles cannot be predictors.
- Training and bootstrap grouping use whole market clusters.
- March 2025 has already been reused in Steps 15A-H. Any apparent directional separation requires a separately frozen future OOS test.
- Orders remain disabled; tester trades must remain zero.

## Frozen verdict vocabulary

- `HIGH_MOVEMENT_FILTER_SUPPORTED` or `HIGH_MOVEMENT_FILTER_NOT_SUPPORTED`
- `DIRECTIONAL_SIGNAL_FOUND`, `DIRECTIONAL_SIGNAL_WEAK`, or `NO_DIRECTIONAL_SIGNAL_FOUND`
- `INCONCLUSIVE_SAMPLE_SIZE` when support is inadequate
- always `OOS_VALIDATION_REQUIRED` and `PRODUCTION_NOT_ELIGIBLE`

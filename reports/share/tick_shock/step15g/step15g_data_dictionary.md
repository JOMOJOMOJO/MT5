# Step 15G compact-share data dictionary

All CSVs are development-only. `step15g_share_hashes.csv` records bytes and SHA-256; every part is below 50 MB.

## Episode labels compact

One row is one subject, decision checkpoint and outcome horizon at primary RR1.2. It is not necessarily an independent trade. Market-cluster grouping must be retained.

- identity: `subject_id`, `subject_type`, `symbol`, `market_cluster_id`, `shock_direction`
- clocks: `decision_seconds`, `horizon_seconds`, `anchor_msc`, `server_day`
- validity: `feature_status`, `feature_reason`, `primary_population`, `control_population`, `fold`
- labels: `episode_class`, `y_cont`, `y_rev`, continuation/reversal result
- first passage: continuation/reversal touch time, gross R, stressed R, MFE and MAE
- causal features: F01-F36, defined by `reports/analysis/tick_shock/step15f/feature_registry.csv`

Blank is unavailable, not zero. `primary_population=true` excludes GBPUSD fallback exposure and requires complete causal features, valid episode status and valid action paths.

## Other files

- `step15g_profitable_continuation_cases.csv`: primary rows with continuation TP first
- `step15g_profitable_reversal_cases.csv`: primary rows with reversal TP first
- `step15g_both_neither_cases.csv`: BOTH or NEITHER primary rows
- `step15g_feature_contrast.csv`: independent descriptive contrasts; no thresholds are candidates
- `step15g_first_passage_summary.csv`: counts, rates, timing and C0/C2 means
- `step15g_oof_predictions.csv`: outer-fold predictions and training-only thresholds
- `step15g_policy_results.csv`: OOF economic policy reconciliation
- `step15g_candidate_registry.csv`: formal candidate status

Cost meanings: `spread_only_r` uses actual Bid/Ask (C0). `stressed_r` adds the registered spread/slippage stress but excludes unavailable formal commission. It must not be reported as formal net expectancy.

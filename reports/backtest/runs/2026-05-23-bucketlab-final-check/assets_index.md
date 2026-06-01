# ExpectedValue LongOnly BucketLab Assets Index

Date: 2026-05-23

## Core EA Files

- Research EA: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Production short EA, protected: `mql/Experts/ExpectedValue_NWave_Scalper.mq5`
- Long baseline EA, protected: `mql/Experts/ExpectedValue_LongOnly_RelativeScalper.mq5`

Important: the production short EA and long baseline EA were not edited during the final check.

## Frozen Candidate Archive

- `reports/backtest/candidates/expected-value-long-bucketlab-candidate-v1/`

Purpose: frozen candidate_v1 evidence. Do not mutate this archive when restarting research.

## Important Presets

Baseline / earlier research:

- `reports/presets/ExpectedValue_LongOnly_BucketLab_candidate_v1_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_candidate_v1_2026_jan_apr.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_3_second_entry_quality_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_5_shallow_candidate_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_5_shallow_candidate_2026_jan_apr.set`

Final-check presets:

- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_ref_v2_5_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_mid_range_family_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_sl_m1_swing_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_sl_m5_swing_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_tp_recent_high_or_r_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_hold_long_r135_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_second_entry_conservative_2025.set`
- `reports/presets/ExpectedValue_LongOnly_BucketLab_final_one_position_control_2025.set`

## Main Result Folders

Candidate v1:

- `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-candidate-v1-2025/`
- `reports/backtest/runs/2026-05-19-bucketlab-candidate-v1-oos/`

v2.5 diagnostics:

- `reports/backtest/runs/2026-05-21-bucketlab-v2-5-2025-nearmiss-diagnostic/summary.md`
- `reports/backtest/runs/2026-05-21-bucketlab-v2-5-oos-nearmiss-diagnostic/summary.md`

Final check:

- `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_plan.md`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_results.md`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_research_decision.md`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_variant_summary.csv`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/bucket_analysis.csv`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/exit_reason_analysis.csv`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/entry_layer_counts.csv`
- `reports/backtest/runs/2026-05-23-bucketlab-final-check/entry_block_analysis.csv`

## Compile Logs

- `reports/compile/ExpectedValue_LongOnly_BucketLab_final_check_compile.log`
- `reports/compile/ExpectedValue_LongOnly_BucketLab_v2_5_nearmiss_diagnostics_compile.log`
- `reports/compile/ExpectedValue_LongOnly_BucketLab_second_entry_quality_compile.log`

## Devlog

- `docs/devlog/2026-05-19-expected-value-long-bucketlab.md`

This file records the research sequence from initial BucketLab through candidate_v1, v2 splits, two-position research, v2.5, OOS failure, and final-check disposition.

## Most Important Files To Read First

1. `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_research_decision.md`
2. `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_results.md`
3. `reports/backtest/runs/2026-05-21-bucketlab-v2-5-oos-nearmiss-diagnostic/summary.md`
4. `docs/devlog/2026-05-19-expected-value-long-bucketlab.md`
5. `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`


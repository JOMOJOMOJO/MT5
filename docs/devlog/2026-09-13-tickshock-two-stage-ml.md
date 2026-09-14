# Two-Stage ML intake and fixed-time label repair

[Preregistration](../research/tick_shock/two_stage_ml_preregistration.md) fixes
Jan–June development and sealed July/August holdout. The prior USDJPY-only
result is not reused as evidence of positive expectancy; all six symbols are in scope.

Inspection found a material label gap: existing technical CSVs contain barrier exits
and 60/300/900-second MFE/MAE, not unconditional 300/600/900-second liquidation quotes.
Inferring fixed-time outcomes from those columns would condition on barrier outcomes.

A separate tester-only collector adds a bounded observer beside the unchanged private
research detector and feature/entry pipeline. It emits six fixed-time records per entered
episode, never raw ticks, and sends no orders. Fresh monthly run IDs are used. Collection
QA compares all original feature values and entry clocks against prior monthly data and
checks independent directional R/pip arithmetic. A failed gate stops subsequent months.

The collector compiled with 0 errors / 0 warnings. The development runner is
`tools/tick_shock/run_two_stage_development_collection.ps1`; evidence/status is under
`reports/backtest/batches/two_stage_development_20260913/`.

Python causal-policy tests cover: no current-score or same-timestamp leakage,
30-day expiry, global position reservation, gate-before-reservation, and time-exit validity.
The analysis driver is `tools/tick_shock/two_stage_ml.py`. It refuses to start until all six
monthly fixed-time QA reports pass, and contains no holdout-reading command.
Its optional watcher stops after development/Python freeze; it cannot launch holdout.

No profitability, model selection, MQL model parity or final holdout result is claimed yet.
R for this new fixed-time primary is one-ATR normalization, not guaranteed loss bounded by
SL. This differs from the previous RR1 barrier study and must remain explicit in reports.

## January gate and explicit resume (September 14)

January completed with 1,628 feature episodes; all original features and entry clocks
matched. The first fixed-time arithmetic gate failed on 970/9,714 uncensored labels:
the fixed 1e-9 R tolerance ignored CSV's 12-decimal price/ATR serialization. The maximum
error was 3.86004e-8 R. An analytical per-row bound (two quote half-LSBs, ATR half-LSB,
R half-LSB and floating arithmetic) explained every difference: outside bound 0.
The old FAIL is retained in `202501/fixed_time_qa_before_precision_audit.json`;
`r_precision_differences.csv` and `r_precision_audit.json` contain the calculation.
No label value, model threshold, collector source or EX5 was changed. Resume verifies
the saved source/binary SHA and starts February, never overwrites January.

Some fixed-time exits cross market closures (January maximum excess ~172,785 seconds).
This is not strict 5/10/15-minute liquidation and must remain a limitation/stratum in
all economic results. No hindsight deletion of these trades has been authorized.

## Development launcher recovery (September 14)

All six collection QA gates passed. The watcher stopped before fitting because Windows
PowerShell classified pandas stderr PerformanceWarning as a terminating error. The
original status is retained as `analysis_stopped_warning_20260914.json` in the batch.
The launcher now captures stdout/stderr separately and checks process exit code.
An explicit `--resume-empty-load` accepts only the two empty output directories and
refuses any existing data/model files. A subsequent actual Python error exposed pandas
copy-on-write: the NumPy feature array was read-only. Requesting an explicit copy fixes
buffer ownership without changing feature values, labels or model design. Timestamped
stderr logs retain both incidents. No model fit or holdout access preceded these fixes.

## Development complete and diagnostic MQL parity

All 180 tasks completed, then all 180 were independently refit: 9,360 comparisons,
zero differences. Independent financial/clock/source-label accounting passed 59 checks.
No adoption gate passed. The frozen diagnostic candidate is ElasticNet SCALE_FREE,
300 seconds, Stage 1 gate 25, FREQUENCY_500: 2,996 forward trades, -0.077865 R/trade,
PF 0.782741. See `docs/research/tick_shock/two_stage_ml_development_results.md`.

Generated MQL inference passed all 15,119 development vectors inside Strategy Tester.
Candidate and model parity harness compile with zero errors/warnings. A January-only
Model 4 wiring smoke is now running in `two_stage_development_smoke_20260914`.
The candidate remains diagnostic and tester-only; July/August remain sealed.

# Two-stage research continuation checkpoint

2026-09-14: work is IN PROGRESS, not a completed research result.

- Branch: research/tickshock/2026-09-13-two-stage-ml.
- Original preregistration/collector commit: 5537e21c.
- January collection: 1,628 feature episodes, 9,732 fixed-time labels,
  including 9,714 TIME and 18 CENSORED. Six records per entered episode.
- Original feature, market-cluster, entry and full barrier-output parity: PASS.
- Original fixed absolute R tolerance failed. Per-row 12-decimal serialization
  bound explains all 970 differences; original FAIL preserved. No label rewriting.
- February–June resume uses identical collector source and EX5.
- Ten Python policy/target/pipeline tests PASS. Core MQL harness compiled but has
  NOT BEEN EXECUTED in Tester yet. Collector compile: 0 errors / 0 warnings.
- ML driver/watcher prepared. Watcher waits for six passing monthly QA reports,
  then starts development fits only. No July/August data is opened by it.
- Candidate adapter and model exporter are prepared, not yet model-compiled:
  TickShockTwoStageModel.mqh is intentionally absent until a model is frozen.
- There is no selected model, profit result, model-parity result, or holdout claim yet.

## Resume without losing evidence

1. Read `reports/backtest/batches/two_stage_development_20260913/status.json`.
2. Inspect each month's `fixed_time_qa.json` and `collection_qa.json`; never
   silently continue after a failure or recreate an existing RunId.
3. Once complete, inspect `reports/analysis/tick_shock/two_stage_ml_20260913/`.
   A background watcher may already have launched `two_stage_ml.py`.
   Do not launch a second development process or overwrite its directory.
4. Run independent recount and `rerun_two_stage_development.py` after freeze.
5. `export_two_stage_model.py` produces the fixed MQL model and development parity vectors.
6. Compile/run CoreHarness and ModelParity in Tester while collection is idle.
7. Compile `ExpectedValue_TickShockTwoStageCandidate.mq5`, run a development wiring smoke,
   freeze all binaries/configuration, commit freeze, then July and August exactly once.
8. Implement/complete detailed interpretation, strata, risk, cost and holdout reconciliation
   reporting; all remain pending. Do not promote this checkpoint to a finished EA.

For rolling calibration, August must inherit July's feature-score state via the
predeclared algorithm, not newly fitted weights or an outcome-adjusted threshold.
Main pipeline source SHA is checked by the waiting watcher. If the driver changes,
it intentionally stops rather than executing an unreviewed replacement.

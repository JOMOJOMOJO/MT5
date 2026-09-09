# Tick-shock technical discovery: development candidate completed

Purpose: keep the shock detector frozen while finding a >=200-trade/month,
RR1 technical-state strategy. The user's development-only EA authorization is
not an OOS/live promotion authorization.

One April research run exported 3,967 episodes and 486 causal features. A
preregistered stability/frequency gate selected a depth-3 tree, not the largest
fitted LightGBM result. Research: 351 trades, +0.07313R after hypothetical0.2pip.
All 3,967 MQL model decisions/scores matched the independent Python reference.

The candidate tester run completed while the conversation was rate-limited;
the completion/report were recovered without restarting MT5 or overwriting the
run. Actual result: 350 trades, +368.28USD, PF1.3037, equity MaxDD123.40USD/1.21%,
closed-equity MaxDD119.22USD/1.17%. With additional0.2pip: +301.81USD, +0.09013R,
PF1.2431. Commission and fee were observed zero; swap was -2.63USD. Remaining
positions0, runtime errors0, compile0/0, actual QA26/26 PASS.

Research and actual orders share all 47,604 shadow outcomes and all feature
values. Actual positions differ: 347 matched, 3 MT5-only and 4 Python-only due
to current-quote cost gates and position-overlap/exit timing. No past quote was
used to manufacture parity. Python replay23 artifacts matched byte-for-byte.

Plateau review: this new technical-state family meets the user's **development**
prototype goal, but not an evidence-based prospective-edge goal. Four purged
forward diagnostics are negative; the selected-cluster CI includes zero and
USDJPY is profit-heavy. Freeze and hand off the model for the user's separate
period testing. Do not extend April feature/threshold searching or call this
production-ready. Tester-only safety is enforced at initialization and send.

Evidence:

- [Results](../research/tick_shock/technical_discovery_results.md)
- [Usage](../research/tick_shock/technical_candidate_usage.md)
- [Actual reconciliation](../../reports/backtest/runs/20260909_tstech_candidate_202504/candidate_reconciliation.json)
- [Trade differences](../../reports/backtest/runs/20260909_tstech_candidate_202504/trade_difference_causes.csv)
- [Lesson](../../knowledge/lessons/tickshock-model-parity-versus-execution-parity.md)

Only this task is committed. The unrelated Step15G EventResponseHarness EX5,
compile logs, suite_results.csv and untracked detection-time harness evidence
remain untouched. The abandoned non-r2 compile-only directory is preserved
locally; it did not start MT5. Exact source ZIP bundles preserve mixed historical
newline conventions and verify against owning commits plus run SHA values.

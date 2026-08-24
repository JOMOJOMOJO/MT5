# Tick-shock Step 14R: pre-Step-15 remediation

## Scope and change boundary

Step 14R repairs the Step 9-14 validation foundation before any Step 15 or
long-OOS work. The branch was created from
`43c4f93ce072c618db92a596e45278cb1d61e96c`. The research EA remains
order-free. No detector threshold, quote-age limit, baseline rule, burst or
pullback rule, four-strategy definition, stop grid, delay grid, spread stress,
RR 1.2, 120-second hold, session, symbol, period, or strategy-selection rule
changed.

The exact parameter comparison is
`reports/qa/tick_shock/step14r_strategy_parameter_comparison.csv`: 43
strategy/execution parameters are unchanged; the eight changed fields are
RunId/folder, source/EX5 provenance, and structured commission evidence.

## Global frontier correction

The implementation now owns three distinct concepts per symbol:

- `last_quote_msc`: timestamp of the last actual quote; used only for quote
  freshness and stale-quote diagnostics;
- `read_through_msc`: end of the range that CopyTicks causally proved complete,
  including a valid empty/quiet range;
- the processed cursor: the last individual quote position, retaining
  same-millisecond multiplicity.

The global safe frontier is the minimum `read_through_msc`, never the minimum
`last_quote_msc`. A quiet symbol can therefore advance completeness without
inventing a quote. A signal still fails its own 500ms freshness rule if its
actual quote is stale. Pagination, history synchronization, CopyTicks errors,
same-ms cursor stalls, page-limit exhaustion, pending loss and final drain are
recorded separately.

A transient CopyTicks error blocks release while its requested range is
unproved. If a later read causally proves that range for every symbol, the
recoverable incomplete-frontier latch clears while the historical failure count
remains diagnostic. Capacity loss, tick drop, cursor stall and page-limit
exhaustion remain permanently invalid.

Regression evidence is versioned rather than rewriting `TS-MERGE-002`:

- `TS-MERGE-003`: quiet-range read-through does not block another symbol;
- `TS-MERGE-004`: a real CopyTicks failure remains fail-closed;
- `TS-MERGE-005`: a transient failure followed by complete causal reread
  recovers without erasing its diagnostic count.

## Order operation identity

The order lifecycle now separates local operation, request, order, deal,
position and position-identifier fields. Entry and time-exit operations have
different request/order identity. Server SL/TP exits do not fabricate a client
request. `DEAL_ADD` may arrive before the caller consumes an OrderSend result;
the first authoritative transaction can bind missing identity and a later
matching result reconciles it. Duplicate deal tickets remain idempotent.

`TS-ORDER-008` protects DEAL-before-result reordering. `TS-ORDER-009` protects
entry/exit operation separation. The final tester observation confirms that
Long/Short expert time-close requests differ from the corresponding entry
request and match the exit `DEAL_ORDER`.

## Validator and evidence integrity

`tools/tick_shock/reconcile_causal_runs.py` is fail-closed. It validates
required files and columns, nullable rules, enums, numeric finiteness, unique
event/scenario identity, references, source/config/run metadata, the exact
executed EX5 archive, and causal invariants. It writes comparison outputs via
temporary files and replaces final outputs only after success.

Twelve corrupted-input cases all terminate nonzero and produce no PASS output:
missing column, blank required value, nonnumeric value, NaN, Infinity, unknown
enum, duplicate event, orphan symbol row, truncated CSV, source hash mismatch,
missing baseline, and missing current run.

The final IDEAL and REALIZABLE directories each archive the exact executed
binary as `executed_EA.ex5`; its SHA-256 is
`96DCFF454976D2E37AF664BC705B65D4BF2FE7E2F3A8B417101615D818615268`.
Both source-hash manifests record implementation commit
`d454622786795a85c21e16a4d154440eef80b48f`.

## Status and commission semantics

The ambiguous `formal_edge_eligible` wording is replaced by
`formal_analysis_eligible`. Validation, causal execution, cost completeness,
analysis eligibility, edge and production eligibility are separate fields.
The implementation schema is `tickshock-research-step14r-v1`; stale
`step06_causal_execution_20260823` revision text is not emitted.

Commission evidence is a structured enum: `UNAVAILABLE`,
`TESTER_OBSERVED_ZERO`, `EXPLICIT_SCENARIO_ASSUMPTION`, or `BROKER_VERIFIED`.
The Step 14R run used zero because EURUSD Strategy Tester deal fields were
observed as zero. That evidence does not cover live Vantage execution or the
other five symbols. Consequently `COST_MODEL_INCOMPLETE` and
`FORMAL_NET_EXPECTANCY_UNAVAILABLE` remain mandatory.

## RED to GREEN evidence

Before the fixes, the new production-path tests reproduced:

- quiet-symbol frontier blocking (`TS-MERGE-003`);
- entry/exit identity collision and transaction-order rejection
  (`TS-ORDER-008`, `TS-ORDER-009`);
- transient CopyTicks failure remaining latched after a complete reread
  (`TS-MERGE-005`).

After the fixes, the final deterministic suite is PASS 86, FAIL 0, XFAIL 0,
XPASS 0, SKIP 9, BLOCKED 0. The nine SKIPs remain actual-terminal-only or
market-condition observations and were not promoted. The research EA and all
11 harnesses compile with 0 errors and 0 warnings. The final 12 validator
negative tests pass.

## Step 14R order observation

Authoritative evidence is
`reports/tests/tick_shock/step14r_order_observation_final/`.

- OrderCheck / OrderSend: 8 / 8 accepted observations;
- entry / exit deals: 6 / 6;
- Long and Short server SL, server TP and expert time close: observed;
- expert time-close operation identity: two distinct exit requests matched the
  exit deal orders;
- commission/fee/swap fields: 12 deal records observed, all zero;
- harness-owned positions at end: zero;
- actual partial fill and actual process restart: NOT_OBSERVED.

The harness is guarded by `MQL_TESTER`, uses minimum volume 0.01 and a dedicated
Magic, and does not add any order function to the research EA.

## March 2025 replay

Authoritative paths:

- IDEAL: `reports/backtest/runs/20260825_ts14r3_ideal_202503/`;
- REALIZABLE: `reports/backtest/runs/20260825_ts14r3_realizable_202503/`;
- comparison: `reports/backtest/runs/20260825_ts14r3_comparison_202503/`.

Both runs are `VALIDATED`. REALIZABLE has zero causal or formal-integrity
violations, zero dropped tick, zero pending-capacity hit, zero cursor stall,
zero duplicate event and an empty pending queue after final drain. The one
transient CopyTicks failure was later causally reread and remains a diagnostic.

The detector/event population is unchanged from Step 7: 62,577 raw candidates,
19 events, 17 symbol clusters, 15 market clusters, 14 valid pullbacks, five
reaccelerations and 11 reversal signals. Event identity and scenario membership
match exactly. Frontier correction intentionally changes execution clocks and
therefore 625 statuses, 190 policy masks, barrier prices/R and outcome counts;
these are marked `INTENTIONAL_EXECUTION_CHANGE`, not hidden as regression PASS.
An independently repeated run using an archived exact binary has zero event or
summary domain mismatches.

REALIZABLE produces 7,128 correlated valid scenario cells: TP 1,261, SL_GAP
2,819 and TIME 3,048, with diagnostic grid mean R -0.299635. Twelve policy-mask
3 cells occur in two events/two market clusters. These are research-grid cells,
not independent trades and not a selected strategy. Statistical n is 15 market
clusters.

GBPUSD has 179 generated-fallback minutes. The EA counted 30,188 M1 minutes;
the tester journal reports 30,187 total minutes, so the fallback rate is 0.5930%
using the tester denominator. Other symbols have no discard warning, which is
not proof of all-real tick coverage.

The REALIZABLE run used about 367.6 seconds, average/max EA memory 10/10 MB,
and wrote 19 event rows / 5,150,562 bytes, 1,186 summary rows / 223,970 bytes,
and zero trade rows / 15 bytes. It emitted no raw-tick or per-second time-series
CSV.

## Formal verdict and stop condition

- `RESEARCH_PIPELINE_VALIDATED_FOR_MARCH_SHADOW_REPLAY`
- `EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- `LONG_OOS_NOT_AUTHORIZED`

Step 14R validates March shadow-replay plumbing, not a deployable trading EA or
edge. Do not start Step 15, long OOS, optimization, threshold changes or
positive-cell selection automatically. The next promotion gate is explicit
review of this evidence, broader commission coverage, remaining order
observations and the independent sample shortfall.

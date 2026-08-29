# Step 15D final QA

## Verdict

Step 15D satisfies its engineering and development-study gates. It does not
satisfy a strategy promotion gate.

- `PROVENANCE_SCHEMA_LINEAGE_VALIDATED`
- `STATE_CONDITIONED_PATHS_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_STATE_CONDITIONED_PATTERN_SUPPORTED`
- `NO_STATE_RULE_HYPOTHESIS_PROMOTED`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

## Verification summary

| check | result |
|---|---|
| final tests | PASS 248 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 9 / BLOCKED 0 |
| compile | 15/15 targets, 0 errors / 0 warnings |
| Step 15D production-path tests | 64/64 PASS |
| independent oracle | 272 checks, 0 failures |
| historical expected changes | 0 |
| Step 15C detector identity | 0 mismatches |
| Step 15C funnel identity | 0 mismatches |
| Step 15C event-response rows | 21,799 |
| market clusters | 10,245 |
| causal/backdate violations | 0 |
| cross-symbol future reads | 0 |
| fold/threshold leakage | 0 |
| duplicate/drop/cursor/capacity violations | 0 |
| order send calls | 0 |

The nine SKIPs are server SL/TP Long/Short, expert time-close Long/Short,
position identity, and two restart observations. They remain unobserved
terminal lifecycle evidence and were not counted as PASS.

## Regression and data accounting

The accepted run is
`reports/backtest/runs/20260829_ts15d_tail_v1_persistent_state_response_202503_r3/`.
The first attempted RunId exceeded the effective MT5 Common Files filename
length for two new suffixes. It produced no usable Step 15D dataset. `r2`
completed but exposed an unintended legacy diagnostic-clock change. That run
was rejected. `r3` separates the legacy frozen funnel clock from the causal
Step 15D processing clock and is the only accepted run. Failed/rejected runs
remain local evidence and are not promoted.

The final behavior comparison has 14 PASS rows and zero mismatches. Frozen
representative counts are detection 10,245, post-burst 10,245 with 10,244
fills, pullback 1,033, and failed-shock reversal 7,282 with 7,281 fills.
Production detector, gate, state-machine, execution parameters, RR 1.2, stop
grid and order behavior are unchanged.

## Causality and leakage

All checkpoint decisions use the first quote at or after target. All strategy
entries are strictly after their signal and at or after processing and
eligibility. Same-millisecond pending quotes are closed with the final quote.
Long uses Ask entry/Bid exit; Short uses Bid entry/Ask exit. Final cluster
breadth is diagnostic only. Decision features use only members confirmed by
the checkpoint decision quote.

Five response-episode chronological folds use no random shuffle and a
120-second purge. March 2025 is entirely development data. The prior Step 15C
internal-confirmation partition is not presented as unused confirmation.

## Candidate audit

Six rules were registered and all 30 fold trials are retained. Two label rules
had Holm-supported and 5/5-sign-stable development lift, but their executable
one-sigma direction rates were only 0.748% and 0.695%. Both fail the causal
Bid/Ask cost screen. Promoted candidates: zero. The result cannot be repaired
by selecting RR, widening barriers, or adding conditions in this step.

## Large artifacts

Three CSVs exceed 50 MB: raw run checkpoint features, the inherited full
event-response output, and the enriched analysis checkpoint table. They remain
local reproducible evidence and are excluded from normal Git; exact sizes and
SHA-256 hashes are in
`reports/qa/tick_shock/step15d/step15d_large_artifacts.csv`. Git LFS was not
introduced and published history was not rewritten. No all-tick or one-second
CSV was generated.

## Stop decision

Step 15D stops here. RR optimization, unused selection validation, locked OOS,
long OOS, production EA changes and real orders are not authorized by these
results.

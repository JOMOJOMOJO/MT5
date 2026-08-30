# Step 15E final QA

## Verdict

Step 15E passes its engineering and development-characterization gates. It
does not pass a strategy-promotion gate.

- `MEDIUM_HORIZON_SHOCK_PATHS_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_MEDIUM_HORIZON_RESPONSE_BIAS_SUPPORTED`
- `NO_MEDIUM_HORIZON_HYPOTHESIS_FROZEN`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

## Engineering evidence

| check | result |
|---|---|
| inherited deterministic suite | PASS 248 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 9 / BLOCKED 0 |
| Step 15E production-path suite | PASS 28 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 0 / BLOCKED 0 |
| combined rollup | PASS 276 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 9 / BLOCKED 0 |
| compile | 16 unique targets: existing 15 (including research EA) plus new harness, 0 errors / 0 warnings; EA recompile also 0/0 |
| independent oracle | 28 rows, 0 mismatches |
| Step 15D event/path/cluster identity | 0 mismatches |
| strategy/execution parameters | 0 differences |
| future read/backdate/drop/capacity/duplicate episode | 0 |
| production order rows | 0 |

The nine inherited SKIPs remain actual-terminal lifecycle observations. They
were not converted to PASS by the research harness.

## Evidence limitations

The run contains 3,151 complete 15-minute symbol episodes and 10,245 inherited
market clusters, not 21,799 independent trades. All 417 GBPUSD episodes are
excluded from primary inference because the journal identifies 179 generated
fallback minutes among 30,187 bars but does not provide their intervals.
Primary N is 2,734.

Matched controls are `NOT_ESTIMABLE`: no causal non-shock path extending to 15
minutes was recorded. UTC session conversion is also unavailable because a
verified broker UTC-offset/DST series was not injected; server-hour breakdowns
are diagnostic only. These limitations are reported, not imputed.

The EA summary counts 10,587,809 ticks while the tester journal reports
10,587,807 total ticks. This two-tick accounting-definition difference is
preserved as a QA limitation and does not alter episode/event identity.

Commission and additional slippage remain incomplete across the six symbols.
Formal net fields remain blank. The 1.25x spread sensitivity is available, but
it is not a substitute for formal net cost evidence.

## Statistical and candidate audit

All primary cohort means are negative from 30 through 900 seconds after actual
Bid/Ask spread. All positive-response Holm-adjusted p-values are 1.0. The
full-cohort 900-second positive fraction improves to 38.5%, but mean executable
movement is -0.868 anchor spreads and its day-block 95% interval is
[-1.105, -0.602]. Leave-one-symbol-out conclusions remain negative, including
when USDJPY is omitted.

No row meets the frozen confidence, multiplicity, 5/5 fold,
leave-one-symbol-out and 1.25x spread requirements. The candidate registry has
zero data rows. No RR, SL or TP was selected.

## Artifact policy and stop

Files over 50 MB are not added to normal Git. Their exact path, size, SHA-256,
RunId, source commit, schema and regeneration command are in
`reports/qa/tick_shock/step15e/step15e_large_artifacts.csv`. No all-tick or
one-second CSV was created.

Step 15E stops here. Selection validation, locked/long OOS, RR optimization,
production EA promotion and real-account orders are not authorized.

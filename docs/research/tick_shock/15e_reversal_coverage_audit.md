# Step 15E reversal-direction and coverage audit

## Verdict

`STEP15E_DIRECTION_AND_COVERAGE_AUDIT_PASSED`

The audit recomputed reversal trades from the recorded entry and exit Bid/Ask;
it did not negate the continuation return. For a Long reversal it used entry
Ask and exit Bid. For a Short reversal it used entry Bid and exit Ask. The
causal-state clock reused its observed entry quote and explicitly inverted the
trade side because Step 15E stored only the shock-direction diagnostic row at
that clock.

Across confirmed, +30s, +60s, +120s and causal-state clocks, and 5/10/15-minute
exits, every `SR-REV-001` mean was negative. Candidate-gate passes were zero.
For example, confirmed reversal means were -0.006738, -0.006610 and -0.005929
absolute price units at 5, 10 and 15 minutes. Therefore the Step 15E stop
decision and formal status do not change.

## Population funnel

The full accounting is:

| stage | eligible | first exclusion |
|---|---:|---:|
| all episodes | 3,151 | - |
| fallback policy | 2,734 | 417 GBPUSD fallback-contaminated/unmappable |
| 300-second primary outcome | 1,204 | 1,530 stale exit quotes |
| 600-second primary outcome | 1,209 | 1,525 stale exit quotes |
| 900-second primary outcome | 1,185 | 1,549 stale exit quotes |

First exclusion reasons are mutually exclusive and reconcile to 2,734 for
each horizon. Completed-M1, causal volatility, direction, spread, duplicate,
missing Bid/Ask, horizon and unexplained exclusions are all zero within the
already-defined primary population.

Accepted/excluded distributions were compared by symbol, broker-server hour,
severity, anchor spread and pre-M1 RMS. The preregistered material-bias screen
was absolute standardized mean difference >=0.5 for continuous variables or
maximum category-share difference >=20 percentage points. Flags were zero.
The largest continuous effect was pre-M1 RMS at 600 seconds (0.486); this is a
visible near-threshold limitation but does not cross the fixed stop boundary.

## Provenance and limitations

The audit uses the accepted Step 15E run and its actual recorded quotes. Event,
episode, path/funnel/cluster identity and parameter comparisons remain at zero
mismatches. GBPUSD remains excluded rather than treating generated fallback as
real ticks. Session timestamps remain broker-server time because verified UTC
offset/DST data is unavailable.

Machine evidence is under
`reports/qa/tick_shock/step15f_step15e_audit/`. No Step 15E production source,
fixture, expected value, strategy, detector, RR or order behavior was changed.

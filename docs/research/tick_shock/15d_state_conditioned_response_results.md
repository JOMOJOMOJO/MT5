# Step 15D state-conditioned response results

## Scope and result

This is a March 2025 `DEVELOPMENT_AND_HYPOTHESIS_GENERATION_ONLY` study of the
unchanged `TAIL_V1_PERSISTENT` detector. It is not unused-period validation,
RR optimization, formal net-expectancy evidence, or production promotion.

Formal status:

- `PROVENANCE_SCHEMA_LINEAGE_VALIDATED`
- `STATE_CONDITIONED_PATHS_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_STATE_CONDITIONED_PATTERN_SUPPORTED`
- `NO_STATE_RULE_HYPOTHESIS_PROMOTED`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

## Population and regression

The final run is
`reports/backtest/runs/20260829_ts15d_tail_v1_persistent_state_response_202503_r3/`.
It retained 21,799 event rows, 10,245 market clusters, 3,286 total response
episodes (3,285 analyzed and one purged), and 112,211 available checkpoint
rows. Step 15C detector features, strategy funnel, event-response identity and
all frozen reachability counts compare with zero mismatches. There were no
order calls.

The 21,798 rows in Discovery and Internal confirmation are explicitly
`ANALYZED_PARTITIONS_ONLY_EXCLUDING_PURGE`. March is wholly contaminated for
Step 15D hypothesis generation; the former internal-confirmation segment is
not represented as unused validation.

All 15 compile targets completed with zero errors and zero warnings. The final
test roll-up is PASS 248, FAIL 0, XFAIL 0, XPASS 0, SKIP 9 and BLOCKED 0. The
nine SKIPs remain actual-terminal observations for server SL/TP, time close,
position identity and process restart; they were not converted to PASS.

## Path classes and state observations

Each event has exactly one primary class. Counts are:

| class | event rows |
|---|---:|
| `FAILED_SHOCK_REVERSAL` | 9,695 |
| `CLEAN_CONTINUATION` | 6,576 |
| `DEAD_OR_TIMEOUT` | 3,746 |
| `PULLBACK_CONTINUATION` | 1,782 |
| `TWO_SIDED_WHIPSAW` | 0 |

The absence of the whipsaw primary class follows the frozen one-sigma/same-tick
definition; origin recross remains available as a secondary flag. It is not
backfilled by changing the class definition after seeing March.

At the episode-primary 1,000 ms checkpoint, two simple empirical rules showed
development-data path-label separation:

- `SR-CLEAN-001`: 698 OOF episodes, clean probability 0.582 versus 0.328
  unconditional, lift 1.773, positive lift in 5/5 folds.
- `SR-REV-001`: 288 OOF episodes, failed-shock reversal probability 0.833
  versus 0.426 unconditional, lift 1.955, positive lift in 5/5 folds.

These are conditional label patterns, not executable strategy candidates.
Both failed the preregistered cost-headroom screen. At the one-sigma executable
Bid/Ask barrier, shock-direction continuation occurred in only 163 of 21,799
detection entries (0.748%), while continuation in the reversal trade direction
occurred in 110 of 15,825 failed-shock entries (0.695%). The prevailing spread
therefore overwhelms a one-local-sigma directional move at entry. No state rule
was promoted.

## Strategy-specific executable paths

Event-row entry counts were detection 21,799, post-burst 21,799, pullback
2,348, and failed-shock reversal 15,825. Market-cluster representative counts
remain the frozen Step 15C funnel: detection 10,245, post-burst 10,245 (10,244
fills), pullback 1,033, and reversal 7,282 (7,281 fills).

The strategy path CSV uses Long Ask entry/Bid exit and Short Bid entry/Ask
exit. At the one-sigma barrier the outcome counts were:

| strategy | continuation first | reversal first | timeout |
|---|---:|---:|---:|
| detection continuation | 163 | 21,635 | 1 |
| post-burst continuation | 157 | 21,641 | 1 |
| pullback continuation | 23 | 2,325 | 0 |
| failed-shock reversal | 110 | 15,714 | 1 |

This table is not net expectancy. Commission is not validated across all six
symbols and the study intentionally does not select SL/RR.

## Causality, validation and artifacts

All recorded decision quotes are at or after their target; all entries are
strictly after signal and at or after eligibility and processing. Future
cluster members and final cluster breadth are not entry features. The five
chronological folds use response episodes, no random shuffle, and a 120-second
purge. Thresholds are calculated on training folds only. Causal, leakage and
candidate-freeze audits all report zero violations.

The full checkpoint CSV is 76,620,401 bytes after analysis enrichment and the
raw run checkpoint CSV is 60,563,599 bytes. Neither is added to normal Git.
Their paths and SHA-256 values are retained in QA evidence. Compact tables,
plot-source CSVs, SVGs, scripts and the deterministic replay configuration are
versioned. No all-tick or one-second CSV was produced.

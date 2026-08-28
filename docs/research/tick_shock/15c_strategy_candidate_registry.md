# Step 15C strategy candidate registry

## Freeze point

- study: Step 15C, March 2025 development data only
- detector: `TAIL_V1_PERSISTENT`
- partition read before this freeze: `DISCOVERY` only
- discovery event rows: 16,913
- discovery market-cluster representatives: 7,350
- discovery response episodes: 2,190
- maximum promotable candidates excluding `NO_TRADE`: 8
- promoted candidates: **0**
- registry decision: `NO_STRATEGY_CANDIDATE_PROMOTED`
- confirmation data inspected before freeze: **no**

This registry is frozen before the one-shot internal-development confirmation.
The confirmation result must not add, remove, or modify a candidate.

## Candidate table

| candidate ID | detector | entry strategy | SL | RR | delay | spread | status | reason |
|---|---|---|---:|---:|---:|---:|---|---|
| `NO_TRADE` | `TAIL_V1_PERSISTENT` | none | n/a | n/a | n/a | n/a | retained | No fully specified executable policy passed the preregistered discovery gate. |

The machine-readable `candidate_shortlist.csv` contains its header and no data
rows. There is therefore no hidden or discretionary candidate outside this
registry.

## Discovery evidence

The six primary cluster/episode outcomes used 10,000 stationary-block bootstrap
replicates, mean block length 4, seed 20260828, and Holm family correction.
None met the preregistered positive-continuation support rule. The 10-second
continuation return was negative (`-4.226735844350868e-06`) with 95% interval
`[-7.1398908571923995e-06, -1.2486951378483446e-06]` and Holm-adjusted
`p=0.0311968803119688`. This is a development-data mean-reversion observation,
not an executable reversal candidate: exact entry-side Bid/Ask, arbitrary stop
grid first touch, delay, spread stress, SL gap, and timeout R cannot be recovered
from fixed-horizon snapshots alone.

The preregistered 2,760 research grid labels are consequently recorded as
`NOT_EVALUABLE_WITH_FIXED_HORIZON_ONLY`, not as losing trades and not as zero-R
trades. Commission remains unverified for formal all-symbol net expectancy.

Gate diagnostics are descriptive, not a gate-removal experiment. Seven
Discovery event rows passed all recorded gates. Leave-one-out reach was 22
without activity and 1,694 without cost feasibility, but no gate is relaxed or
removed in this Step.

## Frozen hashes

- event-response specification:
  `7C8572782B094175347DEDC489B9F2DD5154FE450C5F4FCD5B3921866AFD2DCC`
- analysis implementation:
  `7AA593DE676D3E0627C80F0D5F65370772D14AE950CD26030F3CB35F555899B3`
- candidate shortlist:
  `2B852D0A2D42C7AFC301C6DD2127F4FFB99D451CB06F1A9DA8E609AFB961FDF0`
- primary bootstrap results:
  `A4340E3400B32D73D291BD5983621AC7D171C175EBEA04191915F1093EC529FC`

## Confirmation rule

Internal confirmation is allowed exactly once after this registry commit. With
zero promoted policy candidates it may confirm or fail to confirm the aggregate
conditional-response observation, but it cannot establish strategy edge,
select an RR, or promote a policy. Formal statuses remain
`COST_MODEL_INCOMPLETE`, `FORMAL_NET_EXPECTANCY_UNAVAILABLE`,
`EDGE_UNDETERMINED`, and `PRODUCTION_NOT_ELIGIBLE`.

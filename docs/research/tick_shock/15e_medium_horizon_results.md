# Step 15E medium-horizon response results

## Scope and verdict

This is a March 2025 `DEVELOPMENT_ONLY` characterization of the unchanged
`TAIL_V1_PERSISTENT` detector. It is not selection validation, locked OOS, RR
optimization, formal net-expectancy evidence or production promotion.

Formal status:

- `MEDIUM_HORIZON_SHOCK_PATHS_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_MEDIUM_HORIZON_RESPONSE_BIAS_SUPPORTED`
- `NO_MEDIUM_HORIZON_HYPOTHESIS_FROZEN`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

## Population and regression

The accepted run is
`reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503/`.
It retained the frozen 21,799 Step 15D detector rows, 10,245 market clusters
and every Step 15D path label with zero identity mismatches. Strategy and
execution parameter differences are zero, and the research EA sent no orders.

The causal 15-minute state machine produced 3,151 symbol episodes. All reached
900 seconds, none was purged, and duplicate episode IDs were zero. Active
repeats were features of their existing episode; cooldown observed 1,114
further shocks without allocating new episodes. Symbol counts were USDJPY
1,018, USDCAD 647, AUDUSD 507, GBPUSD 417, USDCHF 314 and EURUSD 248.

The tester reported generated-tick fallback for 179 of 30,187 GBPUSD minute
bars. The affected intervals cannot be mapped from the journal, so all 417
GBPUSD episodes are excluded from primary inference. Primary population is
therefore 2,734 episodes. The saved time is broker-server time; a verified
UTC/DST conversion was unavailable, so session results remain explicitly
server-hour diagnostics.

## Medium-horizon response

The primary response requires a complete episode, causal completed-M1
volatility, an available Bid/Ask checkpoint and no unmappable GBPUSD fallback.
Values below are shock-direction executable movement divided by anchor spread.
Positive means the move cleared the entry spread in the shock direction.

| cohort | horizon | N | blocks | mean spread multiples | positive | day-block 95% CI |
|---|---:|---:|---:|---:|---:|---:|
| all | 30s | 1,306 | 1,204 | -1.007 | 11.4% | [-1.105, -0.921] |
| all | 120s | 1,244 | 1,170 | -0.939 | 22.9% | [-1.049, -0.822] |
| all | 900s | 1,185 | 1,125 | -0.868 | 38.5% | [-1.105, -0.602] |
| `SR-CLEAN-001` | 30s | 387 | 371 | -0.776 | 11.9% | [-0.959, -0.608] |
| `SR-CLEAN-001` | 120s | 365 | 352 | -0.607 | 26.0% | [-0.805, -0.410] |
| `SR-CLEAN-001` | 900s | 343 | 335 | -0.721 | 41.1% | [-1.194, -0.196] |
| `SR-REV-001` | 30s | 610 | 576 | -1.228 | 8.5% | [-1.307, -1.140] |
| `SR-REV-001` | 120s | 591 | 567 | -1.261 | 17.8% | [-1.424, -1.080] |
| `SR-REV-001` | 900s | 526 | 507 | -1.227 | 35.4% | [-1.866, -0.654] |

Longer holding increased the fraction of positive observations, but did not
make the mean executable response positive. Every Holm-adjusted one-sided
p-value for positive response is 1.0. The 30/120/900-second mean is negative
in all five chronological folds for all and `SR-REV-001`. `SR-CLEAN-001` at
900 seconds has one positive fold and four negative folds, so it also fails
stability.

Leave-one-symbol-out results remain negative at 120 and 900 seconds for every
omitted symbol. The aggregate conclusion is therefore neither created nor
reversed by USDJPY. GBPUSD is already absent from primary inference.

## Entry clock and cost headroom

Actual Bid/Ask was used: Long enters Ask and exits Bid; Short enters Bid and
exits Ask. Confirmed, +30s, +60s, +120s and causal-state-transition clocks are
stored separately and never backdated. At the confirmed clock, the all-episode
shock-direction spread-only mean was -0.006855 price units at 120 seconds and
-0.007192 at 900 seconds. At 1.25x spread these became -0.007750 and -0.008092.
No tested clock/cohort combination supplied positive average executable
headroom after the 1.25x spread stress.

Step 15D's one-local-sigma first-touch continuation rate was 0.748%. In Step
15E the all-episode positive executable fraction rises to 22.9% at 120 seconds
and 38.5% at 900 seconds, but its mean remains below zero. Extending the hold
therefore allows more paths to outrun spread at some checkpoints, yet does not
produce stable positive aggregate cost headroom.

Commission and additional slippage are not established for all six symbols.
They are not imputed as zero, and formal net return is blank. Accordingly,
`COST_MODEL_INCOMPLETE` and `FORMAL_NET_EXPECTANCY_UNAVAILABLE` remain binding.

## Controls and limitations

A causal 15-minute non-shock control repository was not recorded in this run.
The prior 120-second controls cannot be extended or repurposed with future
prices. Matched controls are therefore `NOT_ESTIMABLE`, with zero coverage and
no fabricated difference estimate.

The episode summary records MFE/MAE and hit time, recross, causal pre-M1 RMS,
quote count, realized volatility, spread, repeat direction and severity. The
checkpoint table records actual Bid/Ask, quote age and normalized movement.
No all-tick or one-second CSV was written.

## Stop decision

No preregistered cohort/horizon passed positive confidence interval,
family-wise adjusted significance, 5/5 positive folds, all-positive
leave-one-symbol-out and positive 1.25x-spread sensitivity. Candidate count is
zero. Step 15E stops without selection validation, OOS, RR selection,
production EA work or live orders.


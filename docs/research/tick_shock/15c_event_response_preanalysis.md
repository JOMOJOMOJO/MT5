# Step 15C event-response pre-analysis plan

## Scope and fixed starting point

This plan was frozen before generating any new event-response outcome. The
primary detector is `TAIL_V1_PERSISTENT`; its formula, thresholds, tail
calibration, 250 ms persistence rule, and two-second market-cluster rule remain
unchanged. March 2025 remains development data. `TAIL_V1_NOISE_ROBUST` and
`TAIL_V1_RAW` are sensitivity-only; `STRICT_V0` is regression-only.

The analysis population is the 21,799 PERSISTENT event rows and 10,245 market
clusters recorded by Step 15B. A market-cluster representative is the earliest
`confirmed_time_msc`, tie-broken by lexicographically smallest `event_id`.
Primary inference uses representatives and response episodes, never the 21,799
rows as independent observations.

## Units and clocks

- Event: one symbol/detector event row.
- Market cluster: Step 15B cross-symbol/cross-horizon cluster.
- Response episode: the transitive union of representative 120-second windows;
  a new episode starts only when `confirmed_time_msc > current_episode_end_msc`.
- Candidate path is detector diagnosis only.
- Confirmed path begins at PERSISTENT `confirmed_time_msc` and is the earliest
  time at which a strategy could know the detector passed.
- Entry/reference quote is the first real same-symbol quote at or after the
  relevant clock. Candidate-time backdating is forbidden.
- Burst, pullback, reversal, delay, and actual-fill clocks retain the causal
  definitions already validated in Steps 6-15B.
- Shock direction is the detector's frozen LONG/SHORT direction. Future labels
  never become features.

## Path and outcome definitions

Fixed horizons are 250, 500, 1000, 2000, 3000, 5000, 10000, 15000, 30000,
60000, and 120000 ms. No interpolation is permitted. At each target, use the
first real quote at or after the target. Save its timestamp and target lag. A
snapshot is `STALE` if target lag exceeds 1000 ms and `MISSING_END` if no later
quote exists. This 1000 ms bound is an
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

For the reference mid `m0` and future mid `mt`:

- raw return: `log(mt/m0)`;
- continuation return: direction sign times raw return;
- pips use symbol digits (`10*point` for 3/5 digits, otherwise `point`);
- points use the recorded symbol point;
- spread is Ask-Bid at the actual snapshot.

Online MFE is the maximum directional mid change and online MAE is the maximum
opposite-direction mid change from the confirmed reference through 120 seconds.
The first timestamp attaining the final maximum is retained. Origin recross is
the first mid crossing the frozen shock-start mid opposite the shock direction.
No future volatility is used as a denominator. Normalizations are frozen at
confirmation: local sigma, initial shock size, and observed reference spread.

Primary first-passage barriers, in confirmation-time local-sigma units, are the
finite pairs `(0.5,0.5)`, `(1,1)`, and `(2,2)`. Secondary initial-shock-ratio
pairs are `(0.25,0.25)`, `(0.5,0.5)`, and `(1,1)`. Same-tick two-sided hits are
`AMBIGUOUS`, never assigned favorably. All pairs are entered in the trial
registry.

## Dependence, split, and missing data

The frozen episode construction gives 3,286 episodes. Chronological allocation:

| partition | episodes | market clusters | event rows |
|---|---:|---:|---:|
| Discovery | 2,190 | 7,350 | 16,913 |
| Purge | 1 | 1 (`7351`) | 1 |
| Internal confirmation | 1,095 | 2,894 | 4,885 |

Discovery outcome windows end at `1742530331500`. Internal confirmation starts
at `1742530690000`, 358,500 ms later. The purged episode is never analyzed.
These counts and clocks were derived only from identifiers/timestamps, before
new response values existed.

Run-end truncation, stale snapshots, and missing horizons remain explicit and
are excluded only from the affected outcome denominator. Capacity loss, dropped
rows, duplicate rows, or cursor stalls invalidate the run. Overlap is handled by
episodes plus chronological stationary-block bootstrap, not by pretending
clusters are independent.

## Features, hypotheses, and statistics

Only confirmation-time-known features are allowed: severity, adjusted p-value,
shock size, local sigma, noise, efficiency, tick intensity, move/spread, spread
ratio, quote age, trigger horizon/mask, symbol, server hour/weekday, volatility
regime, cluster breadth, prior shock count, and elapsed time since prior shock.
UTC/JST are left blank unless independently proven; current status is
`TIMEZONE_MAPPING_NOT_VERIFIED`.

Primary family (Holm, family-wise alpha 0.05) consists of representative-level
mean continuation returns at 1, 3, 10, 30, and 120 seconds plus the 1-sigma
continuation-first minus reversal-first probability. Secondary conditional
feature/bucket and all other barrier results use BH-FDR at 0.05. Effect sizes,
95% intervals, episode counts, symbol/day/hour concentration, and nearby-bucket
stability are mandatory.

Bootstrap uses 10,000 chronological stationary-block replicates with mean block
length 4 episodes and seed 20260828; block-length 2 and 8 are sensitivities.
Matched-control reuse sensitivities, if used, operate at unique control ID,
without-replacement, and reuse-cap levels 1 and 3. Zero opposite replicates are
reported as `p < 1/(B+1)`.

## Gate and strategy analysis

The order-independent gate mask is fixed as: statistical shock 1, direction 2,
directional burst 4, activity 8, liquidity 16, cost feasibility 32, efficiency
64, persistence 128. Gate thresholds are not changed. Report single-gate pass,
pairwise overlap, fail count, leave-one-out, and reached/not-reached paths.

Reference strategies remain detection continuation, post-burst continuation,
pullback continuation, failed-shock reversal, and no trade. Each is evaluated
across representative clusters with its existing causal signal clock. No signal
and no fill remain distinct.

## Offline execution grid and candidate selection

Path characterization precedes execution analysis. The versioned research-only
grid retains the existing SL grid (1.0 through 12.0 unstressed spread in 0.5
steps), delays 0/100/250 ms, spread multipliers 1.0/1.25, 120-second hold, Bid/Ask
execution, TP limit, SL gap and slippage rules. RR values are fixed at
0.8/1.0/1.2/1.5/2.0. The production default RR remains 1.2.

At most eight non-NO_TRADE candidates may be frozen. This is an engineering
trial-count constraint (`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`). A candidate
must have at least 200 independent Discovery episodes, positive after-observed-
spread expectancy, relatively positive 95% lower bound, same sign at adjacent
SL/RR values, no symbol above 35% of positive contribution, and a fully hashed
rule. If fewer qualify, fewer or zero are frozen. Internal confirmation is run
once only after the candidate-registry commit; candidates are never edited from
its result.

Commission is not fabricated. Outputs distinguish gross, after observed spread,
after spread stress, before unverified commission, and hypothetical commission
sensitivity. Break-even round-trip cost is reported. Until six-symbol broker
commission is established, `COST_MODEL_INCOMPLETE` and
`FORMAL_NET_EXPECTANCY_UNAVAILABLE` remain mandatory.

## Allowed conclusions and prior knowledge

Already observed: Step 15B detector support, matched-control results, existing
funnel reachability, and the 21,799/10,245 population. Not yet observed when this
plan was frozen: signed paths, excursion timing, first passage, conditional
biases, RR-grid results, and candidate confirmation.

Allowed conclusions are exactly the Step 15C status vocabulary in the task,
including `EDGE_UNDETERMINED` and `PRODUCTION_NOT_ELIGIBLE`. This step cannot
claim strategy edge, optimal RR, locked OOS success, formal net expectancy, or
production readiness.

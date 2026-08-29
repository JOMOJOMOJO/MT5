# Step 15E medium-horizon pre-analysis plan

## Frozen scope and null hypothesis

This plan is frozen before any Step 15E outcome is generated. The complete
March 2025 sample is `DEVELOPMENT_ONLY`; it is neither unused validation nor
OOS. The detector remains `TAIL_V1_PERSISTENT`. Its thresholds, formulas,
event/cluster identity, Step 15D path labels, `SR-CLEAN-001`, `SR-REV-001`, the
four existing strategies, Bid/Ask semantics, 120-second strategy hold, RR,
stop/delay/spread grids, risk controls and zero-order research design are
unchanged.

The primary null is:

> Eligible shocks have no stable spread-adjusted directional response from
> 30 seconds through 15 minutes after conditioning on the preregistered Step
> 15D state labels.

No parameter or candidate is selected using an unused validation period in
this step. A finding can only become
`DEVELOPMENT_DERIVED_NOT_VALIDATED`.

## Episode construction

Each symbol has one bounded state machine:

`IDLE -> ACTIVE_15M -> COOLDOWN -> IDLE`.

The first causally confirmed eligible shock while IDLE anchors the episode.
Further eligible shocks while ACTIVE do not start another episode and cannot
change its anchor; they only increment repeat count and update repeat
direction/severity summaries. ACTIVE ends at `anchor + 900,000 ms`. COOLDOWN
ends after 60,000 ms without another eligible shock. A shock during COOLDOWN
restarts the quiet clock but does not create an episode. The last incomplete
episode is `PURGED_END_OF_DATA` and excluded from inference.

These constants are frozen before outcome inspection:

- horizon: 900 seconds;
- quiet/cooldown: 60 seconds;
- checkpoints: 5, 10, 30, 60, 120, 180, 300, 600, 900 seconds;
- quote stale threshold: 1,000 ms target lag or processing quote age;
- same-millisecond quotes: last quote closes that millisecond;
- weekend/missing/fallback observations: explicit unavailable categories.

## Causal medium-horizon scale

The scale is not the 250/500/1,000 ms detector sigma. For an anchor at `t`,
only completed one-minute boundaries no later than
`floor(t/60,000)*60,000 - 60,000` are eligible. Consecutive completed-boundary
mid prices form log returns. The primary scale is the RMS of the latest ten
available completed-M1 log returns:

`pre_m1_rms = sqrt(sum(r_i^2) / n)`, with `n >= 10`.

No current incomplete M1, future quote, interpolated anchor or generated-
fallback observation may enter the primary scale. Insufficient anchors,
invalid prices or invalid numbers are `VOLATILITY_UNAVAILABLE`, never zero.
Point, pip, entry-spread, initial-shock and pre-M1-volatility multiples are
reported separately.

## Outcome clocks and prices

Checkpoint observations use the first real same-symbol quote at or after the
target and preserve target, quote, processing, age and lag. Signed log return
is `direction * log(mid_t / anchor_mid)`. Absolute return and raw long/short
returns are stored separately.

Executable paths use actual Bid/Ask:

- Long enters Ask and exits Bid;
- Short enters Bid and exits Ask;
- entry clocks are confirmed, confirmed +30s, +60s, +120s and the first causal
  Step 15D state transition when present;
- the decision quote only arms the entry; the first later eligible real quote
  fills it;
- primary exits are fixed time, never optimized barriers.

For every entry, report gross-mid, spread-only executable return, known-cost
return and break-even additional cost. Formal net is unavailable unless both
commission and slippage are observed and attributable. Zero observed cost is
not substituted for unknown cost. Spread sensitivity widens Bid/Ask around the
same mid by 1.25x while retaining the same fixed clocks.

## Cohorts and controls

Primary cohorts are only: all episodes, `SR-CLEAN-001` and `SR-REV-001`.
Additional fields (symbol, session, cluster composition, repeat count,
direction agreement, severity, activity and pre-volatility) are descriptive;
they do not authorize a combinatorial search.

Matched controls must match symbol, UTC time-of-day, weekday, pre-volatility
regime, spread, pre-trend and activity. They exclude shock episodes plus purge,
the same market cluster, incomplete/future observations and fallback-derived
primary observations. Pseudo-direction is the sign of a causal short return
fixed before the future control path. Coverage, reuse and unmatched reasons
are reported. If a causally recorded 15-minute control path is unavailable,
the comparison is `NOT_ESTIMABLE`; Step 15D/15B short-horizon controls are not
silently repurposed.

## Statistics and stability

The inferential unit is the non-overlapping symbol episode and the dependence
unit is the UTC market-time block/market cluster. Use five chronological
folds, UTC-day block bootstrap, leave-one-symbol-out, leave-one-day-out,
session splits and contribution concentration. Report N episodes and blocks,
mean, median, positive probability, quantiles, spread-adjusted mean and CI,
adjusted p-values, folds and matched differences where estimable. Explicitly
test whether the result depends on USDJPY. Primary cohort/horizon tests use
Holm FWER 0.05; descriptive tables use BH-FDR 0.05.

## Candidate gate and stop rule

At most three medium-horizon hypotheses may be frozen, and only after path
diagnosis. A frozen row must fully state condition, direction, entry clock,
fixed exit clock, SL/TP/RR/max hold, cost treatment, no-trade rules, March-only
derivation, spec hash and `DEVELOPMENT_DERIVED_NOT_VALIDATED` status. This step
does not optimize RR or stops. If stability, executable cost headroom, sample
support or data quality is inadequate, stop with
`NO_MEDIUM_HORIZON_HYPOTHESIS_FROZEN`.

## Integrity gates

Any future read, backdated fill, duplicate episode, dropped/stalled/capacity-
lost quote, missing provenance, Step 15D identity change, strategy parameter
change or order call invalidates the formal run. Primary inference excludes
generated fallback and reports unknown coverage rather than zero. Broker time
is converted using recorded server/UTC metadata; DST assumptions are explicit.
No all-tick or one-second CSV is emitted.


# Step 15D state-conditioned response pre-analysis plan

## Scope and population

This plan is frozen before generating any Step 15D March outcome. March 2025
is `DEVELOPMENT_AND_HYPOTHESIS_GENERATION_ONLY`; the Step 15C internal
confirmation partition is not unused confirmation in this step. The primary
detector is the unchanged `TAIL_V1_PERSISTENT`. Primary inference uses response
episodes, not event rows. The expected accounting is 21,799 event rows, 10,245
market clusters, 3,286 total response episodes, one purged episode and 3,285
analyzed episodes. The 21,798 analyzed event rows are labelled
`ANALYZED_PARTITIONS_ONLY_EXCLUDING_PURGE`.

The detector formula, thresholds, noise estimator, persistence, clustering,
four strategy state machines, SL/delay/spread grids, RR 1.2 default, 120-second
hold, Bid/Ask execution and order behavior are frozen. Gates may be features;
they are not removed or relaxed. No RR optimization, locked OOS, recent OOS or
production promotion is authorized.

## Decision checkpoints and clocks

Fixed checkpoints are confirmed time plus 500, 1,000 and 3,000 ms. Causal
state-machine checkpoints are burst end, valid pullback, reacceleration
confirmation and continuation invalidation. Each record carries target,
decision quote, processing, quote age, target lag, availability, stale/missing
status, entry eligibility and first executable quote. Fixed checkpoints use
the first real quote at or after target. A decision quote can establish state
but cannot also be used as a backdated fill; entry uses the first causally
eligible quote under the existing execution-clock contract. Quote lag above
1,000 ms is `STALE` (`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`).

Strategy clocks are frozen: detection continuation at confirmation, post-burst
continuation at causal burst end, pullback continuation at reacceleration and
failed-shock reversal at continuation invalidation. Long enters Ask/exits Bid;
Short enters Bid/exits Ask.

## Causal features

At each checkpoint only observations at or before the decision quote are used.
Shock-quality fields are severity, raw/adjusted p, local score/sigma, initial
shock, shock/sigma, shock/spread, trigger horizon/mask, efficiency, intensity,
move/spread, spread ratio, confirmation delay and remaining candidate shock.

Let `d` be +1 for LONG and -1 for SHORT, `m0` the confirmation mid and
`scale=max(initial_shock_size,noise_floor)`:

`extension_ratio = d * (mid_t - m0) / scale`

`retracement_ratio = max_opposite_excursion(confirm..t) / scale`

Online state also retains maximum extension/retracement, origin relation,
first recross/time-since/count, new directional/opposite extremes, two-sided
touch, realized range and realized volatility. Microstructure state retains
non-zero/positive/negative/equal mid updates, directional imbalance
`(positive-negative)/max(1,positive+negative)` (equal updates excluded from the
denominator but counted separately), longest/current signed run, median/latest
interval, post/pre activity ratio, spread normalizations and raw versus
half-tick-noise-robust direction.

Existing gate truths, bitmask, all failures and leave-one-gate-out reachability
are diagnostic features only.

## Cross-symbol causality

Canonical USD sign is positive for rising USDJPY/USDCHF/USDCAD and falling
EURUSD/GBPUSD/AUDUSD. At a decision clock, cluster breadth/coherence includes
only members confirmed by that clock. Final breadth is outcome-only and is
forbidden as an entry feature. Stored fields include causal breadth, USD
strength/weakness counts, coherent share, conflicts, confirmation spread,
composition, single/multi-symbol status and final breadth.

## Path classes and executable barriers

Exactly one primary label is assigned in deterministic priority order:

1. `TWO_SIDED_WHIPSAW`: both 1-sigma sides are touched and origin is recrossed;
2. `PULLBACK_CONTINUATION`: valid pullback then reacceleration/continuation;
3. `FAILED_SHOCK_REVERSAL`: continuation invalidation then reversal barrier;
4. `CLEAN_CONTINUATION`: continuation barrier without valid pullback;
5. `DEAD_OR_TIMEOUT`: none of the above by 120 seconds.

Secondary flags retain all observed components; they do not create duplicate
primary rows. Missing evidence yields `CLASS_UNAVAILABLE`, never a favorable
class. Barrier comparisons retain 0.5, 1.0 and 2.0 confirmation-local-sigma.
Executable first passage is recorded separately for each causal strategy
entry, using Long Ask/Bid and Short Bid/Ask. Same-tick two-sided touch is
`AMBIGUOUS`; missing run end is censored. Outputs include MFE/MAE and times,
origin relation, timeout return and maximum tolerable round-trip cost. Mid
first passage remains diagnostic and is never substituted for executable
first passage.

## Hypotheses, models and thresholds

Primary hypotheses (Holm FWER 0.05) are that causal checkpoint state improves
the probability of its corresponding executable path over unconditional
probability for: clean continuation, pullback continuation, failed-shock
reversal and two-sided whipsaw avoidance. All other feature/class/barrier rows
are secondary BH-FDR 0.05.

Analysis order is unconditional, univariate, two-feature interaction,
low-complexity multivariate, then simple state rule. Allowed models are
empirical probabilities, L2 multinomial logistic (`C=1`, standardized numeric
features, at most 8 features), and a decision tree (`max_depth=3`,
`min_samples_leaf=100`, deterministic seed 20260829). Thresholds are training-
fold q25/q50/q75 plus natural zero/one boundaries; validation data never chooses
a threshold. A rule has at most four conditions. These model limits are
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

## Chronological validation and dependence

Use five chronological response-episode folds, never random shuffle. Market
clusters and response episodes cannot straddle train/test. Purge at least 120
seconds at every fold boundary. Thresholds and preprocessing are fit on the
training folds only. Report out-of-fold probabilities, Brier score, log loss,
calibration, lift, class support, sign agreement and threshold stability.

Sensitivities are leave-one-symbol/day/server-hour-bucket out, volatility
regime, single/multi-symbol and coherent/incoherent cluster. Accuracy alone is
not a promotion metric. Bootstrap is chronological episode block bootstrap,
10,000 replicates, mean block 4, seed 20260829; 2 and 8 are sensitivities.

## Candidate freeze and stop rule

At most six non-NO_TRADE state-rule hypotheses can be frozen; `NO_TRADE` is
retained separately. Minimum support is 200 OOF episodes and 40 per non-empty
fold. A candidate requires same-direction OOF lift, reported effect and 95% CI,
multiplicity support, no single symbol/day/hour dependence, no complete
leave-one-symbol sign reversal, nearby-threshold stability, causal feature
availability, executable Bid/Ask support, non-obviously-insufficient cost
headroom, at most four conditions, and a canonical spec hash.

If none qualify, stop with `NO_STATE_CONDITIONED_PATTERN_SUPPORTED`; do not add
conditions to manufacture candidates. Even a frozen hypothesis remains March-
contaminated and requires later unused-period selection validation plus a
separate preregistered SL/RR study.

## Missing data, integrity and output

Missing/stale/censored values remain explicit. Capacity/drop/duplicate/cursor,
future read, backdate, future cluster member read or threshold leakage fails
closed. No all-tick or one-second CSV is written. State is bounded; output is
one row per event/checkpoint or event/strategy plus compact summaries. No new
raw artifact above 50 MB may be added to normal Git without first stopping and
reporting size, SHA, retention need and LFS requirement.

Allowed conclusions are limited to Step 15D development characterization and
hypothesis freeze vocabulary. `STRATEGY_EDGE_VALIDATED`, `OPTIMAL_RR_SELECTED`,
`LOCKED_OOS_PASSED`, `FORMAL_NET_EXPECTANCY_AVAILABLE` and `PRODUCTION_READY`
are forbidden.

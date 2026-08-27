# Step 15B matched control and strategy conversion results

## Verdict

- `SHOCK_DEFINITION_STATISTICALLY_SUPPORTED_ON_DEVELOPMENT_DATA`
- `TAIL_V1_PERSISTENT_SELECTED_FOR_LOCKED_VALIDATION`
- `STRATEGY_FUNNEL_BOTTLENECK_IDENTIFIED_ON_DEVELOPMENT_DATA`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

This is March 2025 development evidence only. No threshold, strategy, RR, stop
grid, delay grid, spread stress, commission value, or order behavior was changed.

## Exact replay identity

All four Step 15A detector runs reproduced exactly. Across detector feature and
strategy event files, missing, added, and changed identities were all zero.
Strategy/execution parameter differences were zero.

| detector | raw | events | market clusters | strategy events |
|---|---:|---:|---:|---:|
| STRICT_V0 | 62,577 | 19 | 15 | 19 |
| TAIL_V1_RAW | 173,869 | 56,674 | 29,180 | 40 |
| TAIL_V1_NOISE_ROBUST | 74,415 | 23,825 | 11,409 | 10 |
| TAIL_V1_PERSISTENT | 74,415 | 21,799 | 10,245 | 10 |

Evidence: `reports/analysis/tick_shock/step15b/detector_identity_regression.csv`
and `parameter_diff.csv`.

## Matched controls

Matching remained exact on symbol, four-hour server bucket, horizon, estimator,
and volatility regime. Controls within 120 seconds of a shock were excluded;
dimensions and time distance were never relaxed.

| detector | matched / representative | rate | unique controls | support |
|---|---:|---:|---:|---|
| STRICT_V0 | 15 / 15 | 100.00% | 13 | insufficient |
| TAIL_V1_RAW | 28,404 / 29,180 | 97.34% | 6,946 | pass |
| TAIL_V1_NOISE_ROBUST | 11,279 / 11,409 | 98.86% | 4,073 | pass |
| TAIL_V1_PERSISTENT | 10,128 / 10,245 | 98.86% | 3,978 | pass |

STRICT_V0 has too few unique controls and its legacy feature rows do not contain
the 120-second outcome fields, so no formal event-minus-control inference is made.

## Primary matched effects

The independent analyzer used 10,000 chronological stationary-block bootstrap
replicates, mean block length 4, seed 20260826. Holm correction was applied over
the 9 V1 primary hypotheses. All reported `p=0` values mean no opposite-side
replicate was observed and must be read as `p < 0.0001`, not exact zero.

For RAW, NOISE_ROBUST, and PERSISTENT, all three primary effects were positive
after correction: 1-second absolute return, 3-second absolute return, and
120-second realized volatility. For PERSISTENT, mean effects were respectively
`1.5862e-05`, `2.5451e-05`, and `1.20999e-04`; all 95% intervals excluded zero.
The one-second effect was positive in every symbol subgroup. Secondary outcomes
use BH-FDR and remain development diagnostics.

These results support the shock definition as an abnormal-movement detector;
they do not establish a tradable directional edge.

## Funnel bottleneck

For PERSISTENT, 21,799 statistical events became only 10 common-strategy-eligible
events. First failures were activity (15,177; 69.62%), directional burst (4,281;
19.64%), cost feasibility (2,210; 10.14%), and liquidity (121; 0.56%).

Independent counterfactual reachability among representative market clusters was:

- detection continuation: 10,245;
- post-burst continuation: 10,245 (10,244 causal fills before end-of-run);
- pullback continuation: 1,033;
- failed-shock reversal: 7,282 (7,281 causal fills).

This identifies the existing common ingress as the dominant conversion bottleneck.
Counterfactual TP/SL/TIME and net ExpectancyR are not promoted because commission
is not broker-verified for all six symbols and the counterfactual evaluator records
reachability rather than a new execution grid. No strategy rule is changed here.

## GBPUSD sensitivity and integrity

The tester journal exposes only aggregate generated fallback: 179 / 30,187
minutes (0.5930%) for GBPUSD. Exact event-window overlap is not observable from
that aggregate evidence and is reported as such. Excluding all GBPUSD leaves the
PERSISTENT match rate at 98.83% (9,241 / 9,350), so the primary support conclusion
is not dependent on GBPUSD.

All formal runs recorded zero control capacity hits, drops, detector track
capacity hits, duplicate events, pending tick drops, and cursor stalls. Peak
memory was 27-28 MB. Runtime was 456-554 seconds per monthly run. RAW output was
largest: detector features 44.5 MB, controls 17.8 MB, matches 7.0 MB, and funnel
26.5 MB. This is bounded but materially heavier than Step 15A.

## Promotion boundary

`TAIL_V1_PERSISTENT` is selected only as the detector candidate for a future
locked validation. Step 15B stops here. It does not authorize locked OOS, long
OOS, optimization, a new strategy, production trading, or live deployment.


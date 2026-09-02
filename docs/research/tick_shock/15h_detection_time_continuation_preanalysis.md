# Step 15H detection-time continuation pre-analysis

## Audit baseline

- parent branch: `research/tickshock-step15g-economic-path-classification-20260901`
- parent HEAD/upstream: `6e5020be77ff7221d91c996d683e41028b2c7538`
- accepted Step 15G run: `20260901_ts15g_economic_path_r3_202503`
- accepted run source commit: `e9c2968660288c12af03dba770e519c8d012e010`
- baseline deterministic suite re-observed: PASS 361 / SKIP 9 / all other statuses 0
- Step 15G oracle: 52 checks / 0 differences
- detector rows 21,799; market clusters 10,245; episodes 3,151; primary Step 15G episodes 2,228 are not reused as a t0 target.

## Question and scope

At the exact production-path decision time when `TAIL_V1_PERSISTENT` becomes usable, can causal information select `CONTINUATION` versus `NO_TRADE` so that C2 continuation losses fall without discarding more profitable continuation? March 2025 is repeatedly observed development data. Internal OOF results are hypothesis-development evidence only.

No reversal action, delayed/pullback entry, RR search, detector change, existing strategy change, order, OOS, or production promotion is permitted. GBPUSD is fully excluded from primary inference because its 179 generated-fallback minutes cannot be interval-mapped. Matched-control economic paths remain unavailable and are not imputed as zero.

## Fixed analysis discipline

- Unit: one causal episode representative; all-event rows are secondary.
- Dependence: whole market clusters remain in one fold.
- Five expanding chronological outer folds; inner chronological selection only.
- Purge and embargo: 900 seconds plus the configured entry delay; 900,250 ms is used conservatively.
- Primary: delay 0 ms, horizon 900 s, RR 1.2, C2 diagnostic cost.
- Stress: delay 100/250 ms and horizon 300/600 s; they cannot select the winning model.
- Bootstrap: paired market-cluster day blocks, 2,000 repetitions, seed 1502, two-sided 95% intervals.
- Multiplicity: Holm correction over the eight preregistered model/feature-set families.
- Missing features fail closed to `NO_TRADE`; unavailable outcomes are excluded and never relabeled loss/zero.

## Minimum support and stopping

The minimum overall analyzable support is fixed at 2,500 episodes and 2,000 market clusters, with at least 200 evaluable episodes and 25 selected episodes in every outer fold. This is an `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`, chosen to keep a normal-approximation 95% mean-R half-width near 0.04R when the standard deviation is about 1R. Failure is `INCONCLUSIVE_SAMPLE_SIZE`, not a threshold-relaxation trigger.

The candidate gate additionally requires positive selected C2 mean and multiplicity-adjusted lower confidence bound, policy value above both `NO_TRADE` and unfiltered continuation, incremental value over `LIQUIDITY_ONLY`, five-fold support, and no concentration or nearby-threshold/delay collapse. Otherwise no candidate is frozen.

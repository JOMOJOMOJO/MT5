# Tick-shock Step 15A pre-analysis plan

## Document control

- Step: `15A`
- branch: `research/tickshock-step15a-shock-redefinition-20260826`
- base HEAD: `7a04694297a142d04c3beb331ee9049f32b5ab60`
- baseline implementation commit: `d454622786795a85c21e16a4d154440eef80b48f`
- status: `PREDECLARED_BEFORE_V1_IMPLEMENTATION`
- development window: `2025-03-01 through 2025-04-01`
- locked validation and long OOS: `NOT_STARTED / NOT_AUTHORIZED`
- path note: the request's `dev/docs/...` resolves to repo-relative `docs/...`
  because this repository root is already the `dev` directory.

The Step 14R suite was rerun before this document was written: PASS 86, SKIP
9, and no FAIL, XFAIL, XPASS, or BLOCKED result. No production, fixture, or
expected file was changed by that preflight.

## 1. STRICT_V0 definition and responsibility of each gate

For each symbol and each independent 250, 500, or 1,000 ms fixed-grid
detector, `STRICT_V0` uses Mid and the same-horizon 15-minute history ending
2,000 ms before the tested boundary. A candidate becomes an event only when
all six tests pass:

1. absolute price move is at or above the 99.5th percentile;
2. robust Z is at least 3.5, using `1.4826 * MAD` and a one-tick noise floor;
3. directional efficiency is at least 0.65;
4. tick intensity is at least 1.5 times its median;
5. move/current spread is at least 4.0;
6. current spread/five-minute median spread is at most 1.5.

The percentile and robust Z identify a large local movement. Efficiency tries
to distinguish a directional path from oscillation. Intensity describes quote
activity. Move/spread is an ex-ante cost geometry diagnostic. Spread ratio is
a liquidity-state diagnostic. In V0 these statistically and economically
different concepts are nevertheless combined as hard shock gates.

`STRICT_V0` is frozen as a legacy comparator. Its default selector, event
identity, counters, CSV meaning, burst logic, scenario grid, and Step 14R March
result must remain exactly reproducible: 62,577 raw percentile candidates, 19
event rows, 17 symbol clusters, and 15 market clusters.

## 2. Problems in the current definition

- A 300-sample pool has only 1.5 expected observations above a 99.5th
  percentile, so it is not an adequate empirical tail calibration sample.
- One 15-minute pool is used for local scale, percentile, activity, and spread
  comparisons although those quantities have different estimation needs.
- Efficiency, activity, liquidity, and cost geometry determine whether a
  statistical shock exists, preventing study of genuine shocks that are not
  immediately tradeable.
- Fixed price-move histograms are symbol-aware through tick size but do not
  standardize the return by a local diffusive-volatility estimate.
- Ultra-high-frequency Mid may contain quote bounce, isolated bad quotes, and
  tick-size noise. The one-tick floor limits a zero denominator but does not
  distinguish a persistent price displacement from one anomalous quote.
- Three horizons create a multiple-testing family. V0 records overlapping
  clusters but does not correct the detector-level tail probability.
- The FX intraday volatility pattern is recorded only as a session label after
  detection, not conditioned in the tail calibration.

## 3. Null hypothesis and statistical shock

For symbol `s`, horizon `h`, server-time bucket `b`, volatility regime `v`,
and estimator `e`, the null is:

> Conditional on the causal local scale, time-of-day bucket, volatility
> regime, symbol, horizon, and estimator, the current absolute standardized
> return is exchangeable with the historical calibration scores in that cell.

At each 250 ms decision boundary, the family comprises every ready horizon in
`{250,500,1000}` for the chosen estimator. The event-level definition is:

```text
STAT_SHOCK_V1 =
    data_integrity_ok
    AND causal_baseline_ready
    AND causal_tail_calibration_ready
    AND min_horizon_holm_adjusted_tail_probability <= 0.01
```

The primary predeclared family-wise alpha is `0.01`. The nested severity bands
are adjusted tail probability at most 0.01, 0.005, and 0.001. Event count is
not a selection objective.

## 4. Prices, returns, local scale, and tail probability

For a valid actual Bid/Ask quote:

```text
M_t = (Bid_t + Ask_t) / 2
r_t,h = log(M_t) - log(M_t-h)
```

All anchors must be exact fixed-grid anchors, must have source quote age at
most 500 ms, and must be no later than the tested boundary. Blank/invalid is
not converted to zero.

For the noise-robust candidates, the causal pre-averaged Mid is:

```text
Mbar_t = (M_t + 2*M_t-250 + M_t-500) / 4
rbar_t,h = log(Mbar_t) - log(Mbar_t-h)
```

Every constituent grid quote must be valid. `Mbar_t` is timestamped at `t`;
the weights do not authorize a signal at `t-250`. The fixed three-point
kernel is an `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`; the literature supports
pre-averaging as a noise-robust principle, not these exact weights or width.

The short causal scale pool contains same-symbol, same-horizon,
same-estimator, non-overlapping returns over the previous 15 minutes, ending
2,000 ms before `t`. At least 300 valid returns and 299 adjacent products are
required. The bipower scale is:

```text
BV_t,h = (pi/2) * mean_j(|r_j,h| * |r_j-1,h|)
noise_return = tick_size / reference_mid
sigma_t,h = max(sqrt(BV_t,h), noise_return)
score_t,h = |r_t,h| / sigma_t,h
```

`reference_mid` is the tested estimator Mid. A missing, non-positive, stale,
or non-finite input fails closed.

The conditional calibration cell is keyed by symbol, horizon, estimator,
four-hour server-time bucket, and local-volatility regime. The regime is based
on `sigma/noise_return`: LOW `<2`, NORMAL `[2,5)`, HIGH `>=5`. The four-hour
buckets and regime cut points are
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

Calibration is expanding and causal within a run. A score is inserted only
after its event time is at least 2,000 ms old. No future sample, other symbol,
other horizon, other estimator, other bucket, or other regime can fill a cell.
Scores are stored as a bounded histogram with width 0.01 over `[0,50]`; values
above 50 enter the final bin. Equal-bin observations count as exceedances, so
quantization is conservative. For current bin `q`:

```text
p_raw = (1 + count_historical_bins_at_or_above(q)) / (N + 1)
percentile = 100 * (1 - p_raw)
```

At a decision boundary, raw p-values of ready horizons are sorted. Holm's
step-down adjusted value for ordered rank `j` among `m` horizons is the running
maximum of `(m-j+1)*p_(j)`, capped at one, then mapped back to the horizon.

## 5. Calibration sample requirements and uncertainty

The detection cell requires `N >= 10,000`. This gives 100, 50, and 10
expected exceedances at tail probabilities 0.01, 0.005, and 0.001. The 99.9
severity label is valid only at `N >= 50,000`, giving 50 expected exceedances.

The recorded uncertainty is the 95% Wilson half-width for a binomial tail
probability:

```text
h = z/(1+z^2/N) * sqrt(p*(1-p)/N + z^2/(4*N^2)), z=1.95996398454
```

At `N=10,000`, the half-width is approximately 0.001959 for `p=0.01` and
0.001395 for `p=0.005`. At `N=50,000`, it is approximately 0.000280 for
`p=0.001`. The minimum expected exceedance count of 50 and maximum 35%
relative half-width at the 99.5 and valid 99.9 boundaries are
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

## 6. Predeclared detector candidates

| Detector ID | Estimator | Statistical gate | Confirmation | Hard non-statistical gates |
|---|---|---|---|---|
| `STRICT_V0` | existing grid Mid price move | existing six gates | none | all existing six |
| `TAIL_V1_RAW` | raw Mid log return | Holm-adjusted conditional empirical p <= 0.01 | none | none |
| `TAIL_V1_NOISE_ROBUST` | three-point causal pre-averaged Mid | same | none | none |
| `TAIL_V1_PERSISTENT` | noise-robust candidate | same at candidate | next 250 ms boundary | none |

Persistence is confirmed only if all confirmation quotes are valid and:

```text
direction * (Mbar_confirm - Mbar_window_start)
    >= 0.50 * abs(Mbar_candidate - Mbar_window_start)
```

The candidate expires at the next 250 ms boundary. Candidate time and
confirmed time are stored separately; the signal/event time is the confirmed
time and cannot be backdated. The 250 ms interval and 50% retained-move rule
are `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

The selector default remains `STRICT_V0`. One run uses one detector selector.
V1 runs must record RunId, detector ID, schema `tickshock-detector-feature-v1`,
the detector specification SHA-256, and source/EX5 identity.

## 7. Separation of concepts

Each accepted or diagnostic candidate records separate booleans:

- `statistical_shock`: adjusted p passes the selected severity threshold;
- `directional_burst`: existing efficiency is at least 0.65;
- `activity_elevated`: existing intensity ratio is at least 1.5;
- `liquidity_normal`: existing spread ratio is at most 1.5;
- `cost_feasible`: existing move/spread ratio is at least 4.0;
- `strategy_signal`: the unchanged downstream state machine armed a strategy.

For V1, the final five fields do not remove a statistical shock. They remain
continuous values plus categorical diagnostics. A wide-spread event can be
`statistical_shock=true`, `liquidity_normal=false`, and
`cost_feasible=false`.

## 8. Event identity, clustering, and deduplication

- Simultaneous horizons at one symbol/boundary form one V1 candidate; the
  horizon with minimum adjusted p is the trigger and a three-bit horizon mask
  records all horizons that pass the event alpha.
- Same-symbol candidates within 2,000 ms retain the existing symbol-cluster
  rule.
- All-symbol/all-detector candidates within 2,000 ms retain the existing
  market-cluster rule.
- Duplicate key is detector ID, symbol, candidate time, confirmed time, and
  horizon mask.
- Statistical sample size is market-cluster count, never event rows or
  scenario-grid cells.

## 9. False-positive and matched-control design

### Algorithmic null calibration

An independent deterministic oracle will generate 100,000 three-horizon
Gaussian null families and apply the separately implemented empirical-rank and
Holm procedure. The observed family rejection rate must lie in
`[0.0085,0.0115]`. The seed and generator are fixed in the oracle evidence.
This tolerance is an `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`. March market
data are not assumed to be a known no-shock null and therefore cannot alone
prove the false-positive rate.

### Matched controls

For each market cluster, select one deterministic earlier control boundary in
the representative event's symbol, time-of-day bucket, horizon, estimator, and
volatility regime. A control must precede the event, must not pass the 99.0
severity boundary, must be more than 120 seconds from every shock/market
cluster, and must have complete 120-second outcomes. Choose the closest earlier
eligible boundary; ties choose the smallest timestamp. If no such control
exists, the cluster is unmatched rather than silently relaxing the match.

Compare cluster-level event-minus-control values for absolute returns at 1, 3,
10, 30, and 120 seconds, MFE, MAE, realized volatility, spread shift, tick
activity, quote-reversion rate, and cluster duration. Primary outcomes are
1-second absolute return, 3-second absolute return, and 10-second realized
volatility. All others are secondary diagnostics.

## 10. Dependence, bootstrap, and multiple comparisons

The primary confidence interval uses a stationary block bootstrap over the
chronologically ordered market-cluster differences, 10,000 replicates, mean
block length four, and seed `20260826`. The block length and seed are
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

Primary p-values are Holm-adjusted across four detector candidates, three
severity bands, and three primary outcomes (maximum family 36). Secondary
diagnostics use Benjamini-Hochberg FDR at `q=0.05` and remain exploratory.
No strategy P/L enters detector selection.

## 11. Candidate selection rule

A detector can be selected for locked validation only when all are true:

1. causal, future-read, integrity, tick-loss, duplicate, cursor, capacity, and
   provenance violations are zero;
2. the synthetic-null family rejection gate passes;
3. at least 30 independent March market clusters exist at 99.0 severity;
4. at least one primary event-minus-control effect is positive with Holm
   adjusted p <= 0.05;
5. no one symbol contributes more than 50% of market clusters and no one
   market cluster contributes more than 20% of the primary effect;
6. the direction of each passing primary effect is unchanged at adjacent
   severity and its magnitude does not fall below half of the 99.0 effect;
7. the run is exactly reproducible from the archived source, EX5, preset, and
   input evidence.

Items 3-6 are `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`. If multiple detectors
pass, select the simplest and most stable, in order RAW, NOISE_ROBUST,
PERSISTENT unless a more complex candidate has materially better prespecified
robustness. If none pass, report `NO_DETECTOR_CANDIDATE_PASSED`. A numerically
best candidate that fails a gate is `BEST_OBSERVED_BUT_NOT_VALIDATED`.

## 12. Fixed parameters and prohibited adaptation

The following are frozen before any V1 March result is generated:

- horizons 250/500/1,000 ms and 250 ms grid;
- quote age 500 ms and baseline exclusion 2,000 ms;
- 15-minute local-scale pool and 300-return minimum;
- bipower formula, one-tick return floor, conditional cell keys;
- 4-hour buckets and LOW/NORMAL/HIGH regime cut points 2 and 5;
- histogram width 0.01, cap 50, conservative equal-bin rank;
- calibration minimum 10,000 and 99.9-valid minimum 50,000;
- event alpha 0.01 and severity 0.01/0.005/0.001;
- Holm horizon and primary-family corrections; BH secondary FDR q=0.05;
- pre-average kernel, persistence rule, clustering windows;
- matched control rule, 30-cluster gate, stationary-bootstrap settings;
- existing burst, four strategy, SL, delay, spread stress, RR, and hold rules.

If any V1 formula or fixed value changes after a March result is viewed, the
change requires a new detector ID and trial ID, before/after spec hashes,
reason, and an explicit list of already viewed results. Failed and stopped
trials remain in the registry.

## 13. Seen and unseen data

Seen before specification: all Step 1-14R documentation, tests, March 2025 V0
events and scenario diagnostics, including the 19-event/15-cluster and negative
diagnostic expectancy result. March 2025 is therefore development/regression
data only. No V1 March output existed when this specification was fixed.

Unseen and prohibited in Step 15A: every locked validation window, long OOS,
2023-2026 aggregate result, parameter optimization, live execution, and
production order behavior. Locked validation dates must be chosen and frozen
in a later instruction without using Step 15A strategy profits.

## 14. Primary literature and claim boundary

- [Lee and Mykland, Jumps in Financial Markets](https://d3qi0qp55mx5f5.cloudfront.net/stat/docs/tech-rpts/tr566.pdf): motivates standardizing a tested return by a causal local volatility estimate and using bipower variation to reduce contamination from earlier jumps. It does not specify this EA's horizons, buckets, alpha, or sample counts.
- [Barndorff-Nielsen and Shephard, Power and Bipower Variation with Stochastic Volatility and Jumps](https://shephard.scholars.harvard.edu/sites/g/files/omnuum7741/files/split.pdf): supports bipower variation as a way to distinguish continuous variation from jump variation. It does not validate the present fixed-grid online approximation.
- [Ait-Sahalia and Jacod, Testing for Jumps in a Discretely Observed Process in the Presence of Noise](https://www.tse-fr.eu/sites/default/files/medias/doc/conf/fineco/papers_2010/jacod.pdf): shows that microstructure noise changes high-frequency jump statistics and supports pre-averaging as a robustification principle. It does not specify the fixed three-point kernel.
- [Andersen and Bollerslev, DM-Dollar Volatility](https://www.nber.org/papers/w5783): documents pronounced intraday FX activity patterns, supporting time-of-day conditioning. It does not prescribe four-hour server-time buckets.
- [Holm, A Simple Sequentially Rejective Multiple Test Procedure](https://doi.org/10.2307/4615733): supports the step-down family-wise correction across simultaneously tested horizons.
- [Benjamini and Hochberg, Controlling the False Discovery Rate](https://doi.org/10.1111/j.2517-6161.1995.tb02031.x): supports FDR control for explicitly secondary comparisons.
- [White, A Reality Check for Data Snooping](https://users.ssc.wisc.edu/~behansen/718/White2000.pdf): supports treating a searched model family jointly and using dependence-aware bootstrap inference instead of reporting the best unadjusted result.
- [Hansen, A Test for Superior Predictive Ability](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=264569): supports benchmark-relative model-family evaluation and guards against poor alternatives dominating a reality-check comparison. SPA is background; Step 15A uses the simpler predeclared Holm family.
- [Politis and Romano, The Stationary Bootstrap](https://doi.org/10.1080/01621459.1994.10476870): supports random-length block resampling for dependent time series. It does not prescribe mean block length four.

Every exact numerical choice not explicitly supplied by the unchanged V0
contract or a theorem above is an `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

## 15. Permitted completion decisions

The strongest permitted statuses are:

- `SHOCK_DETECTOR_IMPLEMENTATION_VALIDATED`
- `SHOCK_DEFINITION_STATISTICALLY_SUPPORTED_ON_DEVELOPMENT_DATA`
- `DETECTOR_CANDIDATE_SELECTED_FOR_LOCKED_VALIDATION`

Also permitted are `NO_DETECTOR_CANDIDATE_PASSED` and
`BEST_OBSERVED_BUT_NOT_VALIDATED`. Step 15A cannot claim
`OPTIMAL_DETECTOR_PROVEN`, `STRATEGY_EDGE_ESTABLISHED`, `PRODUCTION_READY`, or
`FORMAL_NET_EXPECTANCY_AVAILABLE`. `COST_MODEL_INCOMPLETE`,
`FORMAL_NET_EXPECTANCY_UNAVAILABLE`, and `EDGE_UNDETERMINED` remain mandatory.


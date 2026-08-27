# Step 15A Tick Shock definition V1 - development results

## Verdict

- `SHOCK_DETECTOR_IMPLEMENTATION_VALIDATED` applies to the frozen numerical
  detector core and its production-path deterministic tests.
- `NO_DETECTOR_CANDIDATE_PASSED` is the formal March selection result.
- `EDGE_UNDETERMINED`, `COST_MODEL_INCOMPLETE`, and
  `FORMAL_NET_EXPECTANCY_UNAVAILABLE` remain in force.
- No locked validation, long OOS, optimization, production-order path, or
  promotion was started.

The candidate failure is fail-closed. Exact matched controls cannot be built
from the archived output because non-event control boundaries were not
serialized. The detector feature schema also omitted a dedicated `direction`
column. Neither gap was hidden by relaxed matching, inferred labels, threshold
changes, or a post-hoc detector selection.

## Why the old definition was insufficient

`STRICT_V0` requires six simultaneous gates based on a short 15-minute sample.
A 300-observation pool contains only about 1.5 expected observations beyond a
99.5% threshold, making an extreme quantile unstable; hard efficiency,
activity, liquidity, and cost gates also confound whether a statistical shock
occurred with whether the existing strategy can trade it. V0 furthermore does
not correct its three simultaneous horizons at detector level.

The literature supports the general design, not the exact engineering
constants. Lee/Mykland motivates causal local-volatility standardization;
Barndorff-Nielsen/Shephard motivates bipower variation; Ait-Sahalia/Jacod shows
why high-frequency noise changes jump inference; Andersen/Bollerslev documents
intraday FX volatility seasonality; White and Hansen motivate family-aware,
benchmark-relative evaluation. The exact 250ms grid, kernel, buckets, sample
minimums, alpha, persistence fraction, and bootstrap block length remain
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`.

Primary references:

- https://d3qi0qp55mx5f5.cloudfront.net/stat/docs/tech-rpts/tr566.pdf
- https://www.tse-fr.eu/sites/default/files/medias/doc/conf/fineco/papers_2010/jacod.pdf
- https://shephard.scholars.harvard.edu/sites/g/files/omnuum7741/files/split.pdf
- https://www.nber.org/system/files/working_papers/w5783/w5783.pdf
- https://users.ssc.wisc.edu/~behansen/718/White2000.pdf
- https://papers.ssrn.com/sol3/papers.cfm?abstract_id=264569

## V1 calculation

For horizons 250/500/1,000ms, V1 computes exact fixed-grid Mid log returns.
The robust branch uses the causal kernel
`(M_t + 2*M_(t-250) + M_(t-500))/4`. A 15-minute local pool ending at `t-2000`
provides bipower scale, floored by one tick divided by reference Mid. Scores are
conditioned by symbol, horizon, estimator, four-hour server bucket, and LOW /
NORMAL / HIGH volatility regime. An expanding fixed-bin empirical tail requires
10,000 observations; p is `(1 + inclusive exceedances)/(N + 1)`. Holm controls
the three-horizon family at 0.01. PERSISTENT confirms at the next 250ms boundary
only when at least 50% of the move remains and never backdates the signal.

Efficiency, tick activity, liquidity, cost feasibility, and strategy signal
are separate diagnostics. A statistical event remains recorded even when the
unchanged strategy path is ineligible.

## RED to GREEN and compile

- Initial RED: 1 PASS / 23 XFAIL; V1 production API absent.
- V1 deterministic GREEN after implementation and capacity regression:
  25/25 PASS.
- Full suite: 111 PASS / 0 FAIL / 0 XFAIL / 0 XPASS / 9 SKIP / 0 BLOCKED.
- The nine SKIP cases remain terminal-only observations and were not counted as
  PASS.
- Research EA plus all 11 harnesses: 0 errors / 0 warnings.
- Synthetic-null oracle: 100,000 three-horizon Gaussian families, rejection
  rate 0.009970, inside the predeclared [0.0085, 0.0115] gate.

The first RAW run at commit `dd3048bb` was deliberately aborted after 2,742
active-event-pool exhaustion records. Commit `ec1a65d8` separated bounded
statistical tracking from the unchanged 552-scenario strategy allocation.
`TS15A-SEPARATION-001` exercises that same production eligibility function.
All formal `_r2` runs report event-pool exhaustion, pending hit, tick drop, and
cursor stall as zero.

## STRICT_V0 regression

The March comparator reproduced all frozen values: 62,577 raw candidates, 19
event rows, 17 symbol clusters, 15 market clusters, 14 valid pullbacks, five
reaccelerations, 11 reversals, 7,128 valid scenarios, 324 invalid scenarios,
and diagnostic mean R -0.299635. The 19 event identities and 361 selected event
metric cells have zero mismatches versus Step 14R.

## Detector comparison

| Detector | raw candidates | statistical events | market clusters | strategy events | pullbacks | reaccel | reversal | diagnostic mean R |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| STRICT_V0 | 62,577 | 19 | 15 | 19 | 14 | 5 | 11 | -0.299635 |
| TAIL_V1_RAW | 173,869 | 56,674 | 29,180 | 40 | 28 | 9 | 22 | -0.398246 |
| TAIL_V1_NOISE_ROBUST | 74,415 | 23,825 | 11,409 | 10 | 7 | 2 | 6 | -0.399449 |
| TAIL_V1_PERSISTENT | 74,415 | 21,799 | 10,245 | 10 | 6 | 2 | 6 | -0.381495 |

The large V1 counts are not interpreted as edge or as known false positives:
March market data are not a known null. Noise robustification and persistence
reduce event density, but the prespecified matched-control effect and adjusted
significance cannot be estimated. The maximum representative-cluster symbol
shares are 32.41%, 44.89%, and 46.97% for RAW, NOISE_ROBUST, and PERSISTENT,
respectively, below the predeclared 50% concentration gate.

Severity counts decrease monotonically. RAW has 30,347 / 23,259 / 3,068 rows
at P990/P995/P999; NOISE_ROBUST has 12,710 / 10,001 / 1,114; PERSISTENT has
11,411 / 9,301 / 1,087. These counts do not establish threshold stability of
event-minus-control effects.

## Causality, data quality, and provenance

Across all formal runs, duplicate feature keys, confirmed-before-candidate,
scenario entry-before-eligibility/processing, provenance mismatches, event-pool
exhaustions, pending-capacity hits, dropped ticks, and cursor stalls are zero.
RAW has one end-of-period record without a complete 120-second future; it is
identified rather than silently treated as complete.

GBPUSD contains generated fallback for 179 of 30,187 tester-reported minutes
(0.5930%). The EA independently saw 30,188 GBPUSD M1 minutes. Other symbols
have no discard warning in this journal; absence of a warning is not proof that
every tick is broker-real.

All four formal runs archive the same source commit `ec1a65d8`, identical EX5
SHA-256 `97BF63EF929EDE4B16DEA68DC827A3606F7D802B7A07BF4859DE45FAC173EA46`,
presets, tester configs, reports, journals, source hashes, and output hashes.
The 43 legacy parameter rows were audited per run: 42 strategy/execution rows
remain byte-equivalent and the one changed row is the explicitly allowed
versioned feature-schema provenance. Strategy/execution behavior changes: zero.

## Storage and runtime

The EA retains at most 8,192 recent ticks per symbol, discarding ticks older
than 5 seconds or beyond capacity; the grid ring holds 64 points. V1 causal
return history has compile-time capacity 3,612, with the established default
logical capacities 3,610/1,806/904 for 250/500/1,000ms. Lightweight statistical
outcome tracks are capped at 1,024 per symbol for at most 120 seconds. The heavy
strategy event pool remains 64 and pending merge capacity remains 65,536.

No all-tick CSV or one-row-per-second CSV is produced. Event-level files are
written once per completed statistical/strategy event. March runtimes were
364.547s (STRICT), 526.328s (RAW), 518.375s (NOISE_ROBUST), and 524.266s
(PERSISTENT). EA-reported memory was 27MB average/max; observed whole
MetaTester working set during V1 was approximately 494-531MB.

RAW wrote 56,674 feature rows / 44,225,940 bytes and 40 strategy event rows /
10,812,800 bytes. NOISE_ROBUST wrote 23,825 / 19,114,748 and 10 / 2,708,889;
PERSISTENT wrote 21,799 / 17,378,935 and 10 / 2,709,343. Trade CSVs contain
zero trade rows and 15-byte headers because the research EA remains orderless.
At the observed RAW density, feature plus strategy event CSV is about 55.0MB
per month, approximately 660MB/year before filesystem/compression overhead.

## Matched controls, bootstrap, and selection

The archived feature files do not contain non-event boundaries with complete
120-second outcomes, so the exact closest-earlier controls cannot be selected.
Another detector's events are not substituted as controls. All primary and
secondary matched-control, bootstrap, Holm, and BH cells are therefore
`NOT_ESTIMABLE`; this is documented in `15a_matched_control_spec.md`.

Because the matched-control gate fails, no candidate can be selected for locked
validation even though the synthetic null, integrity, cluster-count, and
concentration checks pass. The strongest correct conclusion is:

`NO_DETECTOR_CANDIDATE_PASSED`

`BEST_OBSERVED_BUT_NOT_VALIDATED` is also withheld because the prespecified
primary effects are unavailable. Long OOS must not start. The next promotion
gate is a separately specified, bounded non-event control recorder followed by
an exact March replay; only then may the predeclared cluster bootstrap and Holm
selection be evaluated.

## Secondary strategy diagnostics

These are `DEVELOPMENT_DIAGNOSTIC_ONLY`. No strategy was selected. All four
detectors have negative scenario-grid mean R, commission evidence remains
tester-observed zero for EURUSD only and unvalidated for the other symbols, and
formal net expectancy is unavailable. The March result neither establishes a
continuation/reversal edge nor justifies threshold, stop-grid, delay, spread,
RR, or strategy changes.

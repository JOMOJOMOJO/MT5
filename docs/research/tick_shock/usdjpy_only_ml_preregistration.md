# USDJPY-only technical ML — preregistration

Registered 2026-09-12 before this study's model fits or May/June outcome reads.

## Scope and sealed evaluation

Use only USDJPY rows from the frozen monthly real-tick technical collection
`reports/backtest/batches/tstech_real_202501_202506_20260910/`.
January–April 2025 are development; May then June are a previously observed
period, but unused holdout for this USDJPY-only study. No pristine OOS claim.
Holdout files must not be loaded before frozen model and freeze-record hashes
are written. No updating after May. Other symbols are not used for fitting,
calibration or USDJPY economic evaluation. Existing six-symbol results are
historical comparison evidence, not new training inputs.

## Frozen search

- Existing causal 486 features; normalized variant removes the same 38 raw-unit
  fields as the preceding study (448 retained). No new features.
- RF, Extra Trees, LightGBM, ElasticNet, Ridge, shallow tree, with the preceding
  study's fixed hyperparameters and seed. Primary target NET_R, two regressors.
  The legacy family name LOGISTIC denotes Ridge for NET_R, not a classifier.
- Five RR1 geometries: 0.5 / 0.75 / 1 / 1.5 / 2 completed M5 ATR14. No other grid.
- Existing executable Bid/Ask labels; primary extra round-trip cost 0.2 pip,
  explicitly a cost assumption, NOT measured commission. Sensitivity
  0 / 0.1 / 0.2 / 0.4 / 0.5 / 1 pip, including an additional 0.2 over primary.
- Existing 3-spread minimum distance, broker checks, TP limit / SL gap / TIME
  first available quote after 900 seconds, and causal entry conventions retained.
- LONG if EV_LONG > EV_SHORT and score >= cutoff; SHORT symmetrically; exact
  ties or insufficient scores mean NO TRADE. No outcome-based side fallback.
- One pending/open position, USDJPY only, in signal-processing order. No size
  optimization; economic equity is fixed 1R per accepted trade.

## Forward fit and frequency

January -> February; January–February -> March; January–March -> April.
Fit the entire prior prefix, purging labels whose latest exit or full 900-second
horizon can reach the next month, and any cluster crossing that boundary.
Imputation, scaling and thresholds use only this fitting prefix. No random split.

Cutoffs: absolute 0 / 0.05 / 0.1 R; training-score percentiles and training
portfolio frequency calibration targeting 100 / 150 / 200 / 300 per month;
ALL (finite scores) as a frequency ceiling diagnostic. Frequency calibration
uses 33 predetermined score quantiles and weekday exposure / 21.75. These are
in-sample score calibrations; forward realized frequency, not target labels,
determines feasibility. No refit after cutoff calibration.

60 configurations x 3 forward months x 12 policies. The same architecture is
finally fit on all available, purged January–April labels and its cutoff
recomputed by the selected, unchanged training-only policy.

## Selection fixed before results

Compute episode and one-position frequency ceilings first; monthly episodes >=
200 is only a necessary condition, not guaranteed tradable frequency.
Rank stable candidates with minimum forward-month trades >=200 first; if none
qualifies use >=150, then >=100. A development candidate additionally needs:
every forward month positive, pooled PF>1, top-five removal positive, no day
accounting for >=35% of positive-day profits, positive expectancy under total
0.4-pip cost, and positive pooled results at both training-score percentile
neighbors (+/-0.05 quantile, bounded to [0,1]). Within this set rank worst-month
EV then pooled EV, then count, then lexical configuration key.

If no candidate clears all gates, freeze exactly ONE diagnostic holdout candidate:
highest frequency tier with a model, then best worst-month EV, pooled EV, count,
lexical key. Do not choose a new candidate after May/June. Report frequency
below 200 honestly. Neighbors and interpretation never become new candidates.

## Evidence and QA

Record data hashes, fitting indices, purges, library versions, source HEAD and
file hashes, weights/trees, preprocessing, cutoff, and geometry in freeze artifacts.
Persist independent model interpretation, independent P/L/portfolio recount,
deterministic refits, no-other-symbol assertions, causal checks and unchanged
freeze hashes. Bootstrap by market cluster and by day; development selection
bias remains and confidence intervals are not promotion evidence.

Interpretation uses forward development only: native importance, permutation,
training-defined bins and interactions; native TreeSHAP if the selected model is
LightGBM, otherwise a pre-holdout LightGBM diagnostic at the selected geometry
is permitted and must not affect selection. Report its distinct identity.

MT5, if implemented, is tester-only with a new wrapper and immutable model;
keep the frozen six-symbol dispatcher to preserve collection clocks, but filter
candidate decisions and orders to USDJPY only. This is an execution dependency,
not other-symbol ML training. Verify Python/MQL inference and training-day wiring
before May/June tester runs. Observed fills and money P/L are separate from
offline fixed-R label results. No demo/live orders, no production promotion.

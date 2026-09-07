# Step 15O Cross-FX Lead-Lag Preregistration

## Research boundary and frozen period

Step 15O asks whether causally available information from the other five USD
pairs adds useful Continuation / Reversal / No Trade information when the
unchanged `TAIL_V1_PERSISTENT` detector confirms a target-symbol episode.

- Development period: `2025-04-01 00:00:00` through
  `2025-05-01 00:00:00` (end exclusive), broker server time.
- Primary symbols: `EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF`.
- Driver: `EURUSD,M1`; tester model: real ticks.
- April 2025 is unused by the Tick-shock / Cross-FX lead-lag family. It was
  used by unrelated EA families, so this is development evidence, not OOS.
- The month is frozen before reading Step 15O outcomes and will not be changed
  after results are known.
- Maximum positive verdict is `OOS_VALIDATION_REQUIRED`. Step 15O always
  remains `PRODUCTION_NOT_ELIGIBLE`.

The detector definition, persistence confirmation, two-second market-cluster
rule, cooldown, baseline and all detector thresholds are exactly those in Step
15N. March 2025 is not reused for economic evaluation.

## Causal clock and as-of join

`t0_msc` is the confirmed persistent-episode decision time. For every target
episode, cross-symbol inputs are built only from quotes already processed by
the global merge and satisfying:

```text
source_quote_msc <= t0_msc
source_quote_msc <= t0_processing_msc
source_processing_msc <= t0_processing_msc
```

The latest eligible quote at or before each requested anchor is used; nearest
future ticks, interpolation, completed-cluster information and retrospective
leader assignment are forbidden. Each source quote time, processing time and
age (`t0_processing_msc - source_quote_msc`) is retained. A target is stale at
more than 500 ms. Each other pair is separately classified at 500 ms, but
missing/stale rows are retained. Primary H1-H4 membership requires all five
other pairs valid and fresh; incomplete context is reported, never silently
dropped.

## Frozen transformations

Positive values always mean USD strength:

- USD base (`USDJPY`, `USDCHF`, `USDCAD`): `usd_return = raw_return`.
- USD quote (`EURUSD`, `GBPUSD`, `AUDUSD`): `usd_return = -raw_return`.

Returns use the latest causal quote at `t0` and at or before the anchor for the
fixed windows 1, 3, 5 and 10 seconds. Each return is divided by that pair's
latest completed M5 ATR14 at t0. An unavailable ATR or anchor remains missing,
not zero.

For each window:

- breadth is the count and fraction of the five other pairs whose USD return
  sign agrees with the target shock's canonical USD sign;
- consensus is the median other-pair USD return / ATR;
- shock-aligned consensus is consensus multiplied by target shock USD sign;
- target residual is target USD return / ATR minus other-pair consensus;
- shock-aligned residual is target residual multiplied by target shock USD
  sign.

## Frozen lead-lag definition

The only lead threshold is an absolute 5-second USD-normalized move of at least
`0.10 ATR`. For each of all six pairs, search causally within `[t0-10s,t0]` for
the first observed second whose preceding 5-second return crosses 0.10 ATR in
the target shock USD direction. No other threshold is evaluated.

- `num_prior_cross_fx_movers`: eligible other pairs crossing before or at t0.
- `first_cross_fx_lead_ms`: `t0 - earliest_other_crossing`; missing if none.
- `median_cross_fx_lead_ms`: median of those causal lead times.
- target rank: order of observed crossing times among all six pairs.
- rank bucket is frozen as `EARLY=1-2`, `MIDDLE=3-4`, `LATE=5-6`, and
  `NO_CROSSING` otherwise. Ties use configured symbol order.

## Frozen hypotheses

All hypotheses use the 5-second family and require five valid, fresh other
pairs.

- H1 Cross-FX confirmation: breadth count >= 4 and shock-aligned consensus > 0.
  Fixed action is Continuation.
- H2 Isolated target shock: breadth count <= 1. Fixed action is Reversal; its
  principal diagnostic is Both-SL / no-trade rejection.
- H3 Target lagging consensus: shock-aligned target residual <= -0.10 ATR.
  Fixed action is Continuation.
- H4 Target overextended: shock-aligned target residual >= +0.10 ATR. Fixed
  action is Reversal.

No alternate breadth or residual cutoff will be selected from April outcomes.

## Frozen executable outcome

Both actions are armed at t0. Entry is the first valid target-symbol real quote
strictly after the decision quote and not before processing eligibility. Long
uses Ask to enter and Bid for barriers; short uses Bid to enter and Ask for
barriers. Geometry is redrawn from executable entry using t0's latest completed
M5 ATR14:

```text
TP = 0.40 ATR
SL = 0.25 ATR
RR = 1.6
deadline = t0 + 900 seconds
```

Outcomes are `TP_FIRST`, `SL_FIRST`, or `TIMEOUT`; simultaneous ambiguity fails
closed. The mutually exclusive episode classes are continuation-only TP,
reversal-only TP, both TP, both SL, and timeout-involved. Spread is already in
the Bid/Ask path. Commission sensitivities subtract 0.02R, 0.05R and 0.10R per
trade. Actual orders remain zero.

## Phase A and frozen gate

Baseline is every eligible shock episode. H1-H4 report episodes, market
clusters, action TP/SL/TIME, Both-SL, tradeable conditional direction, fixed
action R, oracle R and market-cluster bootstrap 95% intervals (10,000
replicates, seed 20260908).

Phase B is allowed only if at least one condition is met:

1. Both-SL rate is at least 5 percentage points below baseline and the
   cluster-bootstrap 95% interval for the reduction excludes zero; or
2. among tradeable episodes, the Continuation/Reversal share differs from its
   baseline by at least 10 percentage points and the interval excludes zero; or
3. a preregistered fixed action improves mean R by at least 0.10R and the
   cluster-bootstrap interval for the improvement has lower bound above zero.

If none passes, verdicts include `CROSS_FX_DIRECTION_SIGNAL_NOT_FOUND` and
`ML_NOT_JUSTIFIED`; Phase B files are emitted as explicit `NOT_RUN_GATE_FAILED`
artifacts rather than fabricated model results.

## Phase B, if gated in

Only LightGBM and logistic regression are allowed. `MODEL_X` uses the frozen
Cross-FX family; `MODEL_X_PLUS_EXISTING` adds the already-defined same-symbol
features. Action rows are episode x Continuation/Reversal, but statistical n is
the market cluster.

Chronological expanding cluster folds are fixed at training 0-40% / validation
40-55%, 0-55 / 55-70%, 0-70 / 70-85%, and 0-85 / 85-100%. A no-trade threshold
is selected using training rows only. Fixed model settings follow Step 15M:
logistic `C=1`, balanced classes, 2,000 iterations; LightGBM 200 trees,
learning rate 0.03, 15 leaves, depth 4, minimum child 50, fixed seed 20260908.
No model, hyperparameter, window, symbol, session or week selection is allowed.

Primary evaluation is realized R, including cost sensitivities, fold stability,
Both-SL rejection and conditional direction. AP/AUC and importance are
secondary.

## Success and promotion boundary

Success requires incremental OOF economic improvement over same-symbol inputs,
better Both-SL rejection, better direction choice within tradeable episodes,
multiple-fold support, non-fragile cluster intervals, cost robustness and no
unexplained single-symbol dependence. A positive April development result can
only justify a later completely unused-period OOS. It cannot validate OOS,
production, live execution or slippage.


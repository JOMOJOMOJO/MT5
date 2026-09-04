# Step 15N Post-Shock Delayed Decision Preregistration

## Question and phases

Step 15N asks whether observing the real post-shock path for 15, 30, 60, or
120 seconds leaves enough executable opportunity to choose continuation,
reversal, or no trade. This is a new delayed-entry hypothesis, not a revision of
the Step 15M immediate-entry result.

Phase A is oracle feasibility without ML. Phase B is permitted separately for a
checkpoint only when Phase A shows economically meaningful remaining opportunity.
A checkpoint that fails Phase A receives no prediction model.

## Frozen checkpoints and clocks

The only checkpoints are 15, 30, 60, and 120 seconds after causal episode t0.
For each checkpoint:

```text
checkpoint_target_msc = t0_msc + delay_ms
decision_quote_msc = first valid same-symbol real quote at/after target
decision_processing_msc = first time the EA can causally process that quote
entry_eligible_msc = max(decision_quote_msc,
                         decision_processing_msc + submit_latency_ms)
entry_quote_msc = first valid same-symbol real quote at/after eligibility
                  and strictly after the last decision-feature quote
```

The primary submit convention is the next real tick; no March-derived latency
is selected. Same-millisecond quotes are grouped and the last quote is used
before closing a decision snapshot. Quote lag and processing-to-entry lag are
persisted. No checkpoint row is silently removed.

## Geometry and horizons

- Primary ATR: latest completed M5 ATR14 causally available at decision time.
- TP: 0.40 decision ATR from executable entry.
- SL: 0.25 decision ATR from executable entry.
- Long entry uses Ask and exits are evaluated on Bid.
- Short entry uses Bid and exits are evaluated on Ask.
- Primary deadline: `t0_msc + 900000`.
- Secondary diagnostic only: `entry_quote_msc + 900000`.
- A t0-frozen ATR geometry is a secondary attribution diagnostic.
- TP_FIRST = +1.6R; SL_FIRST = -1R; TIMEOUT uses executable deadline
  Bid/Ask mark-to-market R.
- Stored Bid/Ask includes spread. Observed tester commission is zero; live
  Vantage commission remains unvalidated. Sensitivities subtract 0.02R, 0.05R,
  and 0.10R per trade.

## Eligibility and preservation

Every source episode/checkpoint remains represented with one of at least:
`ELIGIBLE`, `NO_DECISION_QUOTE`, `STALE_DECISION`, `FEATURE_UNAVAILABLE`,
`ENTRY_QUOTE_UNAVAILABLE`, `ENTRY_AFTER_DEADLINE`, `PATH_CENSORED`, or
`DATA_INTEGRITY_INVALID`. Invalid Bid/Ask, fallback quotes, future processing,
and incomplete paths fail closed. Eligibility totals and reasons must reconcile
to all 2,696 source episodes at each checkpoint.

## Phase A oracle

Each eligible episode/checkpoint has continuation and reversal action outcomes.
The mutually reported path classes are continuation-only TP, reversal-only TP,
both TP, both SL, and timeout involved. Oracle value permits no trade:

```text
oracle_r = max(continuation_r, reversal_r, 0)
```

This is an upper bound, never an implementable strategy. Required metrics are
eligibility, independent market clusters, each action result, both-SL rate,
oracle trade count, TP, mean/total R, PF, positive rate, cluster-bootstrap CI,
and symbol/session/week/fold distributions. Step 15M t0 results remain the
immediate-entry baseline.

No numerical March threshold defines feasibility. A checkpoint is absent when
TP-first opportunity is negligible, both-SL dominates, remaining opportunity
is insufficient, or modest cost sensitivity removes almost all value. Weak and
present classifications must disclose their qualitative rationale.

## Causal features and forbidden outcomes

Decision features use only t0-preexisting causal fields plus the real quote path
from t0 through the decision quote. They include return, MFE/MAE-to-decision,
range, retracement, current range location, extreme updates, origin recross,
path length/efficiency, directional tick ratios, realized movement/volatility,
recent acceleration, spread evolution, and tick activity. Every feature has an
availability/source timestamp not later than decision processing time.

Remaining MFE/MAE, future barrier outcome, future first-touch time, and future
excursion are evaluation-only fields and prohibited predictors. Phase B action
alignment follows Step 15M, with candidate-direction signed fields flipped and
directionless liquidity/activity fields unchanged.

## Validation and Phase B gate

- Reuse the Step 15L/M four chronological expanding market-cluster folds.
- All checkpoints/actions for an episode and all episodes in a market cluster
  remain in one fold.
- Random split, SMOTE, AutoML, broad tuning, new delays, and date/week predictor
  features are prohibited.
- Each checkpoint is a separate strategy and separate model.
- LightGBM is primary and logistic regression is baseline, using no greater
  complexity than Step 15M.
- A no-trade threshold, if evaluated, is selected on each fold's training data
  only. Validation results never select their own threshold.
- Fixed training selection-rate diagnostics of 1%, 2%, 5%, and 10% may be
  reported separately.

Primary policy metrics are trades, TP/SL/TIMEOUT, TP rate, mean/total R, PF,
maximum consecutive losses, positive folds, and cluster-bootstrap CI.
Classification AP, ROC-AUC, direction correctness, and score enrichment are
secondary.

## Promotion gate

A checkpoint can justify a later frozen unused-period OOS only if oracle
feasibility exists, a causal no-trade policy has positive validation expectancy,
several folds improve, later March does not collapse, trade count is meaningful,
and cost stress does not destroy the result. March cannot promote a delay to a
production parameter. Step 15N always remains `PRODUCTION_NOT_ELIGIBLE`.

## Data-generation decision

Step 15K/L aggregate outputs do not preserve the +15-second decision quote, the
strictly later entry tick, the complete decision-time feature path, or exact
post-reentry first-touch ordering. Therefore a minimal research-only checkpoint
module and one formal March real-tick run are required. Detector definition,
episode identity, production trading behavior, thresholds, and actual order
count remain unchanged.

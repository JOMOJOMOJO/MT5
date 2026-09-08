# Tick-Shock Technical Feature Discovery: frozen development design

Date: 2026-09-08. Base: 10440ed9. Development period: 2025-04-01 to
2025-05-01, six default FX symbols, EURUSD M1 real-tick driver. April is reused
development data; no OOS or live validation claim is permitted.

## Question and scope

Can completed-bar technical state select absolute LONG, SHORT or NO TRADE with
at least 200 actual non-overlapping monthly trades and positive cost-stressed
net expectancy? The user explicitly authorizes broad technical feature/model
discovery and a development-only EA candidate. Existing detector definitions,
episode suppression and cooldown are frozen. This is a separate strategy family
from symmetric OCO and Cross-FX prediction.

## Data and causal clocks

One formal MT5 research run exports hundreds of causal features per episode and
both executable directional outcomes. Bar sources are bounded completed M1,
M5 and M15 bars, each open time plus timeframe <= shock t0. Missing features
remain blank. Indicator periods/definitions are frozen in the feature module
before formal outcomes are inspected. No target-symbol or cross-symbol future
features enter the matrix. Source close times and availability are exported.

Signal event, signal processing and source quote times are retained. Entry uses
the first subsequent same-symbol real quote with time > t0 and source quote time,
and time >= signal processing + submission latency. No synthetic grid quote is
an entry. Both directions share the quote; LONG buys Ask and exits Bid, SHORT
sells Bid and exits Ask. TP is limit-price execution; SL and time exits use the
first available executable side, including gaps. Same-millisecond ticks retain
their CopyTicks order; entry/exit cannot precede recognition. No actual orders
are sent by the research EA.

## Geometry and economic selection

RR is exactly 1:1. Candidate absolute distances are 0.25, 0.50, 0.75, 1.00,
1.50 and 2.00 times latest completed M5 ATR14. Distance is rounded outward to
tick size once and the identical distance is applied to SL and TP. No fine grid
is added after inspection. Entry-relative executable MFE/MAE at 60, 300 and 900
seconds, first touch and time-to-touch determine which of this coarse set is
economically reachable. Primary maximum holding time is 900 seconds after entry.
Distance < 3 times entry spread or invalid broker protective distance causes
an explicit rejection, never an implicit stop widening. Stops are checked from
current Bid for Buy and current Ask for Sell. Spread is embedded in outcomes.

Commission evidence remains explicitly scoped to observed symbols/accounts.
Absent six-symbol actual commission, primary research metric deducts a declared
0.2-pip round-trip allowance; 0, 0.1, 0.5 and 1.0 pip are sensitivity cases,
not claims about actual commission. Candidate EA tester deal costs must be
observed and reported separately.

## Search and candidate gate

Bounded methods: univariate/bin exploration, feature correlation, interactions,
regularized logistic models, shallow trees and small LightGBM models. Model
complexity and grid are set in the analysis script before formal evaluation.
All fitted development performance is labeled as such; purged chronological
cross-fit performance is a separate diagnostic, not a silently required OOS gate.
Training-only imputation and 900-second purge avoid leaking labels across
cross-fit boundaries. Feature importance cannot establish causal market effects.

Select one direction by predicted expected net R, otherwise NO TRADE. Fixed
score thresholds define runtime rules; retrospective monthly Top-N selection
is only a frontier diagnostic. Greedy chronological portfolio simulation permits
one global position and no retrospective ranking using later signals. Report
200/300/500 and broader frequency frontier, including gates that fall below 200.

A candidate must have >=200 deployed monthly trades, net expectancy >0 and
PF>1, positive net after removing the five best trades, no day accounting for
>35% of positive daily profit, at least 20 trades in each of four chronological
segments and at least three positive segments. Nearby score thresholds must
also retain >=200 trades and positive net. Prefer simpler qualifying rules.
This is a preregistered operational definition of the user's stability criteria,
not proof of an OOS edge. No candidate is manufactured if none qualify.

## Conditional EA and QA

If a candidate qualifies, export exactly its feature ordering, preprocessing,
model/rules and fixed threshold into MQL5. Verify Python/MQL signal parity and
compile, then backtest the same month with actual tester orders, global one
position, small fixed risk and bounded holding. Reconcile trades, costs, PF and
DD; default live trading remains disabled. Any mismatch is diagnosed before
claiming EA reproducibility. The user will run other periods later.

QA covers feature causality, entry eligibility, source hashes, detector/episode
identity, duplicate episodes, cluster provenance, Bid/Ask first touch, arithmetic,
bounded storage, actual order absence in research, deterministic fixtures and
independent recalculation. Preserve task-scoped source/evidence in a dedicated
branch, document rejected ranges, then commit and push.

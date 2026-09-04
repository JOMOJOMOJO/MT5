# Step 15M Direct Action TP-First Prediction Preregistration

## Purpose

Step 15M tests whether causal information available at the frozen Step 15K/L
entry convention can rank the executable action value of continuation and
reversal directly. It does not promote an EA, alter production strategy logic,
or tune the March sample into a production rule.

## Frozen population and geometry

- Development population: the 2,696 Step 15L analysis-ready episodes.
- Each episode expands into exactly two rows: `ACTION_CONTINUATION` and
  `ACTION_REVERSAL`; expected action rows are 5,392.
- Entry and exit use the Step 15K/L executable Bid/Ask convention.
- ATR is the completed M5 ATR14 frozen at causal `t0`.
- TP distance is 0.40 ATR, SL distance is 0.25 ATR, and maximum holding is
  900 seconds.
- `TP_FIRST` is the positive binary target. `SL_FIRST` and `TIMEOUT` are
  negative for classification, while realized R remains +1.6, -1.0, or the
  executable 900-second mark-to-market R respectively.
- The stored path is allowed only for target construction. No future path,
  MFE, MAE, barrier outcome, or target-derived field may enter predictors.

## Frozen feature transformation

Step 15L causal features are reused. Direction-bearing features are transformed
from shock-direction coordinates to candidate-action coordinates by multiplying
by `action_sign`, where continuation is +1 and reversal is -1. Directionless
spread, ATR, activity, severity, and efficiency fields are unchanged. Every
transformed field is catalogued by the analysis implementation.

The registered ablation groups are:

1. `A_STEP15L_EXISTING`
2. `B_ACTION_MOMENTUM`
3. `C_SPREAD_ACTIVITY`
4. `D_STRUCTURE_RANGE`
5. `E_FULL`

## Validation and leakage controls

- The Step 15L four-fold chronological expanding walk-forward boundaries are
  reused.
- Both action rows of an episode remain in the same fold.
- All episodes and actions sharing a market cluster remain in the same fold.
- Train/validation episode overlap and market-cluster overlap must both be zero.
- Random splitting is prohibited.
- Fold-local imputation, scaling, encoding, and model fitting are required.
- March date/week is diagnostic only and is not a predictor.

## Models

- Logistic regression is the linear baseline.
- LightGBM is the primary nonlinear model, using the frozen Step 15L model
  complexity and seed unless the action-row formulation requires only a
  mechanical adaptation.
- Continuation-only and reversal-only LightGBM models are secondary diagnostics.
- A three-class continuation/reversal/no-trade view is optional and cannot
  replace the registered binary action formulation.
- PyCaret, AutoML, broad hyperparameter search, and March threshold optimization
  are prohibited.

## Registered action policy diagnostics

For every OOF episode, score both actions, select the higher score as
`best_action`, and retain `best_score`. Report results without adopting a
production cutoff for:

- Top N: 25, 50, 75, 100, 150, 200, 300, 500.
- Score thresholds: 0.20, 0.25, 0.30, 0.35, 0.40, 0.50, 0.60.

Each frontier reports trades, independent market clusters, selected direction,
TP/SL/TIMEOUT, win rate, mean and total R, PF, maximum consecutive losses,
symbol mix, session mix, cluster-bootstrap confidence interval, and positive
folds. The theoretical TP break-even rate ignoring timeout return is 38.46%.
Scores are rankings, not calibrated win probabilities.

## Cost convention

Spread is embedded in the executable Bid/Ask path. Strategy Tester deal fields
observed commission equal to zero, so gross R and observed-tester net R are
equal. Live Vantage commission remains unobserved. Sensitivities subtracting
0.02R, 0.05R, and 0.10R per trade are diagnostics only. Stored paths do not
prove exact SL gap or exit slippage and that limitation must be reported.

## Required comparisons

On the identical OOF episode population compare:

1. always continuation;
2. always reversal;
3. Step 15L Clean-score Top N plus continuation;
4. Step 15L Clean-score Top N plus reversal;
5. Step 15M direct-action score plus best action;
6. two-stage Clean selector then direction model, if its frozen OOF artifacts
   permit a leakage-free comparison.

Fold, week, global-without-symbol, global-with-symbol, and USDJPY-only results
are diagnostics. USDJPY-only cannot rescue a failed global primary result.

## Required QA

- 2,696 episodes and 5,392 action rows.
- Continuation TP-first = 84; reversal TP-first = 104; total positive rows =
  188; both-actions TP-first = 0.
- Feature timestamp violations, target-leakage predictors, duplicate
  episode/action keys, episode fold overlap, cluster fold overlap, and OOF
  chronology violations all equal zero.
- Research orders and trades equal zero.
- Reproduce the Step 15L Top-327 audit: continuation TP 23, reversal TP 22,
  both SL 282.
- A deterministic rerun must produce byte-identical tabular outputs after
  excluding explicitly recorded environment metadata.

## Interpretation gate

Possible research labels include `DIRECT_ACTION_SIGNAL_FOUND`,
`DIRECT_ACTION_TRADE_EDGE_FOUND`, `DIRECT_ACTION_SIGNAL_WEAK`,
`DIRECT_ACTION_SIGNAL_NOT_FOUND`, `NO_TRADE_FILTER_SIGNAL_FOUND`,
`DIRECTION_SELECTION_SIGNAL_FOUND`, `USDJPY_SPECIFIC_EDGE_CANDIDATE`,
`REGIME_INSTABILITY_CONFIRMED`, and `OOS_VALIDATION_REQUIRED`.

Regardless of the March result, Step 15M remains `PRODUCTION_NOT_ELIGIBLE`.
Only a frozen, previously unused-period OOS test can support later promotion.

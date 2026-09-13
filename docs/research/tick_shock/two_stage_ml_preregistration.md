# Tick-Shock Two-Stage ML — preregistration

Status: design fixed before new fixed-horizon outcomes are collected or inspected.
Base: 317ca5bb0a58d52cd44aee576d7672a47918caaa.

## Frozen scope

Development: January–June 2025, six symbols EURUSD/GBPUSD/USDJPY/AUDUSD/USDCAD/USDCHF.
Five expanding forward folds February–June; fit and preprocessing use prior months only.
July and August are sealed final holdout; no data/outcome inspection before full model/export freeze.
The detector, episode/cluster rules, global dispatcher and 486 completed-bar technical features
are the private frozen source used in the previous study, unchanged.

## Required new labels

Existing technical_outcomes.csv records barrier exits; its 60/300/900 MFE/MAE columns
do not provide unconditional 300/600/900-second liquidation quotes. They cannot be substituted.
A separate no-order collector will observe the same production tick stream and entry convention,
writing first available Bid/Ask at entry+300/600/900 seconds, source timestamp, MFE/MAE,
time-to-MFE and censoring flags. No raw tick CSV. No reconstructed nearest/backdated fill.
The added observer must not modify detector or existing barrier calculations.
Collection parity uses symbol+t0 identity, feature values and original entry quote.
Differences require investigation before fitting.

## Targets and bounded search

Primary exits: unconditional fixed time 300/600/900 seconds; no TP and no emergency SL in
this primary experiment. R is a **normalization unit of one completed M5 ATR14**, not a
guaranteed maximum loss. Tester sizing uses 10 USD per one-ATR move; no live deployment.
No additional exit grid will be introduced after results. Time exits are first observable
quotes; gaps/long holds are retained and separately reported, not backdated.
Net labels include observed Bid/Ask and an additional assumed 0.2 pip round-trip cost.
Sensitivity: 0/0.1/0.2/0.5/1.0 pip; not a claim about actual commission.

Stage1 target: max(realized net R LONG, realized net R SHORT), a hindsight training label,
never an entry-time feature. Predict with the same family as Stage2. Stage1 learned score
gates compare training quantiles 0/25/50%; zero-quantile means no Stage1 filter (ablation).
Stage2: separate LONG/SHORT direct NET_R regressors; train on all eligible prior episodes,
not on hindsight profitable episodes. Choose larger prediction, equal/nonfinite => NO TRADE.
Families: Ridge, ElasticNet, RandomForest, ExtraTrees, LightGBM, shallow DecisionTree.
Use fixed prior-study hyperparameters; FULL486 and SCALE_FREE448, no new indicators.
Three horizons; 36 family/variant/horizon settings, five folds, three Stage1 gates.

Stage2 thresholds compare training-only score quantiles and training-only portfolio-frequency
calibration at 100/150/200/300/500 per month, plus zero expected-return threshold diagnostic.
Do not select monthly top-N using validation outcomes or future month's score distribution.
Report realized monthly frequency rather than treating targets as quotas. Threshold-neighbor
diagnostics are predefined adjacent training quantiles; no holdout threshold tuning.
Global single pending/open position; score ties and same-time competition deterministic.
Unexecutable chosen side is rejected, never switched after observing opposite outcome.
Purge prior-month labels until all three horizons mature; keep market clusters out of both
fit and validation when overlapping. No random split; fit-only imputation/scaling.

## Selection and evidence

Prefer positive pooled forward EV/PF>1, each month >=200 trades, >=3 positive months,
positive total after removing top five profits and additional 0.2 pip stress (0.4 total),
worst-month EV > -0.1R, no symbol >50% of positive profit, stable nearby thresholds.
If no PASS, freeze one DIAGNOSTIC using frequency tier, worst-month EV, pooled EV,
then deterministic config name; label it not adopted. Never optimize on July/August.
Separate Stage1 gate vs no gate and model direction vs constant LONG/SHORT controls.
Family/horizon/frontier/strata/score-shift/cost reports include rejected candidates.

Freeze JSON/PKL, preprocessing, both scores, percentile calibration, feature list,
exit/horizon/sizing/position logic, generated MQL, source commit and SHA before July.
Test-only EA refuses non-MQL_TESTER initialization; research collector sends no orders.
Development-wide Python/MQL parity and compile 0 errors/0 warnings required.
Final order tests July then August use identical binaries/model; no live/demo orders.
Independent financial recount, deterministic refit, input/source hashes, documentation and
scoped commit/push required. Results do not imply live/OOS production eligibility.

# Step 15G Economic Path Pre-analysis

Status: preregistered before the Step 15G first-touch run. March 2025 is development data only.

## Frozen upstream definition

The detector is `TAIL_V1_PERSISTENT`. Its thresholds, persistence rule, 15-minute episode state, market clusters, 36 Step 15F features, 12 registered interactions, completed-bar EMA20/EMA50/ATR14 calculations, 60/120-second decisions, Bid/Ask semantics, and all strategy/execution inputs remain unchanged. No outcome, MFE, MAE, future return, or path label is an entry feature. The research EA remains order-free.

## Existing-artifact decision

The formal Step 15F r3 files contain fixed checkpoint quotes, episode MFE/MAE, their hit times, and an older fixed-barrier first-passage study. They do not contain the complete quote path required to order touches of the risk-scaled Step 15G barriers. Reconstruction from extrema or checkpoint quotes is forbidden. A new MT5 real-tick run with online first-touch recording, a new RunId, schema, and label-spec hash is therefore required.

## Registered questions

Primary: at 60 or 120 seconds after a persistent shock, does a causal continuation or reversal action reach an economically meaningful 1.2R target before its stop, using executable Bid/Ask prices and a fixed risk rule?

Secondary: how do 1.0, 1.5, and 2.0R targets and 300, 600, and 900-second exits change first-passage outcomes; which pre-existing causal features distinguish profitable paths from failures and matched non-shock controls?

## Registered path contract

- Decisions: 60 and 120 seconds after the shock anchor.
- Entry: arm on the decision quote; fill on the first strictly later real quote for the same symbol. Backdating is invalid.
- Actions: continuation follows shock direction; reversal uses the opposite direction.
- Maximum exits: 300, 600, and 900 seconds from the shock anchor.
- Risk distance: `max(0.25 * completed-M5 ATR14, 4.0 * entry spread, broker StopsLevel * point)`.
- The ATR fraction and spread multiple are engineering assumptions to be validated, not optimized values.
- Primary RR: 1.2. Secondary diagnostic RRs: 1.0, 1.5, 2.0.
- SL is rounded away from entry to the symbol tick grid. TP is derived from the rounded executable risk and rounded outward so realized RR is at least requested RR.
- Long entry is Ask; Long exits and barrier tests use Bid. Short entry is Bid; Short exits and barrier tests use Ask.
- TP gaps fill at the target as a limit-equivalent research rule. SL gaps fill at the first executable quote; adverse exit slippage is added only in C2.
- A pending touch is held until the next millisecond. If both barriers are observed at the same `time_msc`, the primary result is conservatively `SL_FIRST`; the secondary diagnostic is `AMBIGUOUS_SAME_TICK`.
- Timeout uses the first executable quote at or after the registered horizon. Missing, stale, fallback, non-causal, or incomplete paths are `INVALID_PATH` with a reason.
- Outcomes: `TP_FIRST`, `SL_FIRST`, `TIMEOUT`, `AMBIGUOUS_SAME_TICK`, `INVALID_PATH`.
- MFE/MAE and their times are measured from the executable entry on the action's exit side.

## Cost contract

- C0: observed Bid/Ask spread only. This is the primary economic-path label.
- C1: C0 plus documented commission/fee. C1 is formal only for symbols with broker/account evidence; otherwise unavailable.
- C2: Bid/Ask spread widened to 1.25x around Mid, documented commission/fee, one tick adverse entry slippage and one tick adverse exit slippage.
- The Step 13 tester observed zero commission/fee on EURUSD deals only. It does not establish six-symbol live commission. No assumed commission is promoted to evidence.
- Where commission is unavailable, preserve maximum additional break-even cost and statuses `COST_MODEL_INCOMPLETE` and `FORMAL_NET_EXPECTANCY_UNAVAILABLE`.
- Swap is excluded because all registered horizons are at most 15 minutes.

## Labels

For each decision and horizon, `Y_CONT=1` only when continuation is C0 `TP_FIRST`; `Y_REV=1` only when reversal is C0 `TP_FIRST`. The primary 1.2R pair maps to `CONT_ONLY`, `REV_ONLY`, `BOTH`, `NEITHER`, `AMBIGUOUS`, or `INVALID`. Secondary-RR success is never unioned into the primary label. Cases, failures, both/neither cases, and matched controls remain in the analysis population.

## Model and validation registry

- Separate Y_CONT and Y_REV models.
- Elastic-net logistic regression and shallow gradient boosting only; probability calibration only when supported inside training folds.
- Expanding chronological five-fold evaluation at episode/market-cluster granularity.
- Purge is at least the evaluated horizon; embargo is at least 15 minutes.
- Preprocessing, feature selection, model tuning, and action thresholds are training-fold only.
- Deterministic seed: 20260901.
- Report leave-one-symbol-out, leave-one-day-out, day/market-block bootstrap confidence intervals, and Holm correction for the registered comparison family.
- OOF policy chooses continuation, reversal, or no trade from expected R; test-fold outcomes never tune its threshold.

## Candidate gate

At most three human-readable rules, each with no more than four causal predicates. A candidate requires at least 200 eligible episodes, at least 100 positive-class episodes, adequate independent day/market blocks, positive mean and lower 95% OOF stress ExpectancyR, Holm-adjusted p below 0.05, positive every chronological fold and leave-one-symbol-out slice, no fatal leave-one-day-out dependency, positive 1.25x-spread result, adequate additional cost headroom, matched-control improvement, and adjacent-bucket stability. Any March-derived candidate is `DEVELOPMENT_DERIVED_NOT_VALIDATED`.

Allowed conclusions are development-data characterization or a frozen hypothesis for later selection validation. `STRATEGY_EDGE_VALIDATED`, optimal barrier claims, locked-OOS claims, production readiness, and trading are forbidden. Persistent statuses are `EDGE_UNDETERMINED` and `PRODUCTION_NOT_ELIGIBLE`.

## Registered hashes

The feature registry is frozen to Step 15F hash `074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597`. The label-spec hash is computed from `15g_economic_path_spec.md` after this preregistration and injected into the run preset. Trial changes require a new trial ID and must not overwrite this trial.

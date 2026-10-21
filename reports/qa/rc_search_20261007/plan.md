# RelativeContinuation v2: fixed parameter study

## Authorization / identity

The user requested bug fixes, instrument-independent parameters and optimization. This successor is `mql/Experts/RelativeContinuation.mq5`, derived from quality12b M15, **not** the old M5/M1 ThreeWave EA. Original quality12b and frozen reports remain available for comparison. Do not load a legacy `.set` into v2; use the complete new preset.

## Frozen before execution

- USDJPY / M15, one position, round-long bucket only. Other inherited buckets stay OFF.
- All 36 price-distance inputs now use closed M15 ATR(14). Candle proportions, ADX/RSI, percent returns, RR, risk percentages and bar counts remain dimensionless. Sessions remain broker-server hours; these require review when changing broker.
- Initial ATR coefficients were an engineering conversion of the old numeric defaults divided by 10, **not** fitted ATR estimates and not equivalent trades. They are starting hypotheses.
- The former psychological 50-pip grid becomes a zero-origin grid of `InpGridStepAtr × closed ATR`. It is recalculated each decision, not a stored support/resistance line. This changes signal semantics and must be evaluated as a new variant.
- Baseline window range >=1.5 ATR, EMA distance <=1.2 ATR, grid step 5 ATR. Upper wick >=0.50 and lower wick <=0.10 retained. A long entry on this upper-wick pattern is unusual but was the original hypothesis, not a proven coding inversion.
- Risk 0.65% Equity; daily cap 3%; peak drawdown cap 12%; no automatic small-account risk increase, no rounding up to minimum lot. Daily cap is latched until next broker day; peak cap remains latched. One strategy/symbol instance; simultaneous portfolio deployment is not validated.
- ATR is bar shift 1 only. Pivots retain the existing asymmetric equality handling and span+1 scan start; no pivot rule change.

## Search (18 combinations)

| Input | Fixed values |
|---|---|
| Max spread / ATR | 0.10, 0.20, 0.30 |
| SL / ATR | 1.5, 2.2, 3.0 |
| RR | 1.0, 1.5 |

One engineering smoke run, then 18 search runs on 2023-01-01..2025-01-01, then 18 validation runs on 2025-01-01..2026-10-01: 37 tester jobs. Exhaustive fixed-input backtests implement the grid search; MT5 genetic optimization is not used. Full account/order replay includes changed position occupancy, spread, costs and risk caps. Continuous periods preserve cap state within each run, so a cap hit and later zero months are real study outcomes, not removed data.

Rank using **only** 2023–2024: annual >=36 trades, annual net>0 and PF>=1.1 first; then worst annual average price R, total net, deterministic cell ID. Display three candidates even if all fail eligibility, labelling failures. Validation results cannot influence selection. Annual net/PF includes reported commission/swap; price R is separately labelled and excludes cash costs.

Monthly minimum 20 executions remains a separate goal; zero months are retained. 2025/2026 are known periods, not fresh OOS. All 18 validation runs are predeclared to avoid adaptive reruns; only train-selected cells are used for validation conclusions. No automatic preset adoption or live activation.

## Diagnosis and QA

Record round signal reasons before execution gates, and record spread/ATR, positions, daily entries and risk locks. Count spread-blocked actual signals separately from all blocked bars. Overlapping gates and changed later occupancy prevent interpreting these counts as guaranteed missed trades.

Require compile 0/0; frozen source/inputs; report identity and input echo; strict single-position deal reconciliation; runtime-error scan; planned-risk budget checks. Mixed/generated history is retained with quality labels, not promoted to real-tick evidence. Failed smoke or any report audit stops the batch. No installed terminal is changed or stopped.

After review, reject unstable/low-frequency results rather than extending the grid after seeing validation. Gold and other symbols require their own contract/session/history tests before operational use.

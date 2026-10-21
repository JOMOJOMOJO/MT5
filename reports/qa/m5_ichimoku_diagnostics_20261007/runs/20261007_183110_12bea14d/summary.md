# M5 / M15-H1-H4 descriptive observer

No context filter, adaptive RR or parameter search. Known periods; not OOS.

- Raw candidates: 1666; actual executions: 217.
- Shadow: {"n": 1666, "n_closed": 1664, "excluded": 2, "executed": 217, "win_rate": 0.40024038461538464, "mean_price_r": -0.13267682709300516, "pf_price_r": 0.7434547651449278, "mean_tp_capped_price_r": -0.13268511621767362, "mean_horizon_mfe_r": 0.9555093685501737, "mean_horizon_mae_r": -1.316097631763923, "horizon_reach_1r": 0.38235294117647056, "horizon_reach_1.2r": 0.30612244897959184, "horizon_reach_1.5r": 0.20888355342136855, "horizon_reach_2r": 0.11284513805522209}
- Actual: {"n": 217, "net": 4.980000000000217, "pf": 1.0008547140569573, "win_rate": 0.4838709677419355, "mean_price_r": 0.006895721960872668, "mean_tp_capped_price_r": 0.005111021357856491, "pf_tp_capped_price_r": 1.0120212832012425, "overshoot_trades": 1}
- Mean actual monthly count: 4.82; minimum: 0.

## Interpretation
Use candidates_with_context.csv for all raw signals including spread/cap/position rejections.
Use trades_with_context.csv for broker-report executions and actual cash costs.
Shadow is a fixed-entry minute-Bid approximation, includes spread but excludes commission/swap/margin and broker rejection.
AMBIGUOUS_M1 (both SL/TP touched in the exit minute), invalid stops and END_CENSORED remain rows but are excluded from expectancy.
Horizon MFE/MAE covers 18 M5 bars, including after an earlier barrier exit; it is a label only, not pre-entry information.
TP-capped R is an outlier diagnostic, not a new exit replay. Negative gaps remain uncapped.
UNKNOWN positions include inverted/zero ranges; no synthetic range is substituted.
Hours are broker-server clock, NOT UTC/JST or DST-adjusted sessions. Tick quality is recorded per run.

Statistics include yearly marginals and predeclared joint regime/spread/time cells. Cells below 30 rows are flagged;
30 is a warning threshold, not proof of reliability. Shared periods/nearby candidates are dependent.
Do not select the best of these many cells. Require consistent yearly effect, enough independent samples and new-period confirmation.
No condition is promoted and no profitability claim is made.

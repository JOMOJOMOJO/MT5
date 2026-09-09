# Tick-Shock Technical Feature Discovery → EA: development results

Period: 2025-04-01 to 2025-05-01. April reused development; no OOS/live claim.
Verdict: `DEVELOPMENT_TESTER_CANDIDATE_ONLY`; `OOS_VALIDATION_REQUIRED`; `PRODUCTION_NOT_ELIGIBLE`.

## Population and design

Frozen TAIL_V1_PERSISTENT: 40,217 statistical detections, 3,967 episodes, 3,746 episode market clusters. 486 causal technical features and 47,604 LONG/SHORT × distance labels.
The labels are not independent trades. Single-position/pending simulation determines deployable frequency. Episode keys, recognition clocks and cluster provenance match Step15P exactly.
One formal feature/outcome MT5 run: 31m33.199s, 14,085,619 tester ticks, 793 MB terminal/tester memory. Application summary measured average 33.398 MB/max34 MB (different scope).
Real-tick mode was used; generated fallback minutes were NOT_OBSERVED. Absence of a discard warning is not proof of zero generated ticks. All six symbols were monitored. Research orders=0.
Completed M1/M5/M15 bars only; 486 features include relative values and cross-timeframe/shock interactions. Six equal-distance geometries were frozen before outcomes; no fine-grid rescue.
Commission across all six symbols was not observed in the research-only run. Research primary net R deducts an explicitly hypothetical 0.2-pip round-trip allowance; spread is already embedded in Bid/Ask.

## Search and selection

15 fitted method/geometry pairs, 165 threshold candidates; 78 had >=200 trades and positive development EV; 41 passed all preregistered gates.
The 0.25 ATR grid had insufficient executable training labels and was not fitted. Extremely narrow distances mostly fail the preregistered 3-spread guard.
Selected `g3_SHALLOW_TREE_absolute_0`: 351 trades, win rate 57.26%, net expectancy +0.073127R, total +25.667494R, PF 1.193757, closed-equity MaxDD 12.974213R.
LONG=92; SHORT=259; TP=141; SL=116; TIME=94. Net pips=437.5000; these cross-symbol pips are descriptive, not equal-currency P/L.
Best-five-trades removed: +20.703515R. Largest positive-day share 15.30%; 3/4 positive segments, minimum segment trades 52.
The selection rule preferred a depth-3 tree over more complex fits, not the largest fitted EV. The most profitable >=200-trade fit was a LightGBM cell with poor temporal frequency coverage; it was not silently promoted.
At runtime choose the greater LONG/SHORT predicted net R only if >=0; exact ties/both below zero mean NO TRADE. Broker/cost/position/risk checks can still reject an armed signal.

### Fitted frequency frontier (not a promotion table)

| minimum_trades | status | method | trades | expectancy_r | pf | candidate_gate |
| --- | --- | --- | --- | --- | --- | --- |
| 200 | EVALUATED | LIGHTGBM | 257 | 0.724948 | 6.92661 | False |
| 300 | EVALUATED | LIGHTGBM | 337 | 0.584035 | 3.95501 | False |
| 500 | EVALUATED | LIGHTGBM | 568 | 0.381734 | 2.78933 | True |
| 800 | EVALUATED | ELASTICNET_LOGISTIC | 813 | 0.00603089 | 1.02577 | False |
| 1000 | NO_THRESHOLD_HAS_THIS_FREQUENCY | nan | nan | nan | nan | nan |

### Selected model nearby thresholds

| threshold | trades | expectancy_r | pf | candidate_gate |
| --- | --- | --- | --- | --- |
| -0.1 | 351 | 0.0731268 | 1.19376 | True |
| 0 | 351 | 0.0731268 | 1.19376 | True |
| 0.05 | 200 | 0.131912 | 1.39852 | False |
| 0.1 | 200 | 0.131912 | 1.39852 | False |
| 0.2 | 0 | nan | nan | False |
| 0.3 | 0 | nan | nan | False |
| 0.166239 | 200 | 0.131912 | 1.39852 | False |
| 0.000335403 | 351 | 0.0731268 | 1.19376 | True |
| 0.000335403 | 351 | 0.0731268 | 1.19376 | True |
| -0.144136 | 841 | -0.0805641 | 0.82264 | False |
| -0.144136 | 841 | -0.0805641 | 0.82264 | False |

### Features used by the selected trees

| feature | importance |
| --- | --- |
| m15_ema20_sma_gap_atr | 0.32455 |
| m5_spread_atr | 0.267417 |
| m15_spread_atr | 0.265155 |
| m15_atr7 | 0.184801 |
| m1_bar_range_atr | 0.166881 |
| m5_atr14_pct64 | 0.161722 |
| m5_roc5_pct | 0.15458 |
| m1_ema10_sma_gap_atr | 0.15455 |
| m1_ema50_sma_gap_atr | 0.134912 |
| m5_roc10_atr | 0.0987279 |
| m1_m5_ema20_slope_product | 0.0867041 |

Importance means contribution to the fitted trees, not causal direction evidence. Raw ATR values can implicitly identify a symbol. USDJPY contributes a large part of the selected development profit; this is not established currency-independent edge.

## Geometry and timing

Selected TP=SL=1.0 × latest completed M5 ATR14 at t0, tick-rounded outward. Reject <3 entry spreads; protection distance checks use Bid for Buy and Ask for Sell. This coarse distance trades reachability against costs; see `path_geometry_diagnostics.csv` and `outcome_funnel.csv` for every original grid.
Target hold900 seconds. Selected research trades: average536.342s, maximum912.677s, no weekend-held trades. Across all unselected raw labels, quote gaps can cause much longer holds (maximum173691.211s). The engine closes at an available quote, never invents a deadline quote.
Actual candidate waits until after dispatcher returns and sends using current SymbolInfoTick. It never sends at a historical replay quote. This stricter deployment adapter can differ from the first-eligible research quote. Server TP price improvement, stop gaps, TIME timing and account-currency conversion also differ.

### Research cost sensitivity

| extra_cost_pips | trades | expectancy_r | pf |
| --- | --- | --- | --- |
| 0 | 351 | 0.0931427 | 1.25265 |
| 0.1 | 351 | 0.0831348 | 1.22287 |
| 0.2 | 351 | 0.0731268 | 1.19376 |
| 0.5 | 351 | 0.0431028 | 1.1103 |
| 1 | 351 | -0.00693714 | 0.983225 |

## Actual same-month MT5 candidate

| metric | actual |
| --- | --- |
| trades | 350 |
| wins | 203 |
| win_rate | 0.58 |
| net_profit | 368.28 |
| total_r | 38.5137 |
| expectancy_r | 0.110039 |
| pf_money | 1.30367 |
| pf_r | 1.30131 |
| maxdd_closed_r | 12.6861 |
| maxdd_closed_money | 119.22 |
| long | 93 |
| short | 257 |
| tp | 142 |
| sl | 114 |
| timeout | 94 |
| hold_mean_seconds | 537.78 |
| hold_max_seconds | 906.226 |
| commission | 0 |
| fee | 0 |
| swap | -2.63 |
| extra_cost_pips | 0 |

Actual commission/fee/swap are observed history values, not the hypothetical research allowance. Candidate cost-sensitivity independently adds the 0.2-pip allowance on top of these observed costs.
Additional0.2pip: 350 trades, expectancy +0.090129R, money PF 1.243064.
Model signal rows=3967; QA=26 checks/0 failures. Matched trade keys=347, MT5-only=3, Python-only=4.
Exact signal/feature parity and exact trade/fill parity are different claims. Read `python_trade_comparison.csv` and `candidate_qa.csv`; differences are retained, not replaced with simulated prices. MT5 HTML has floating-equity drawdown; the table above uses closed-trade normalized R and account-money drawdown.

## Generalization warning

| fold | trades | expectancy_r | pf |
| --- | --- | --- | --- |
| 1 | 59 | -0.124269 | 0.707374 |
| 2 | 12 | -0.139527 | 0.681664 |
| 3 | 38 | -0.288881 | 0.508966 |
| 4 | 12 | -0.131386 | 0.722335 |

These purged forward diagnostics are all negative for the chosen rule. The fitted selected-cluster bootstrap95% CI is approximately [-0.0240,+0.1635]R and is not selection-adjusted. Development positivity does NOT establish prospective positive expectancy.
The user explicitly allowed a development-month EA candidate. Accordingly the EA was built, but no production promotion, OOS claim, live/demo order or additional period search is made. The next gate is frozen-model testing on an unseen period, not retuning this April result.

## QA and reproduction

Feature harness24 PASS; execution harness35 PASS; Python specification15 PASS; full MQL model parity3967/3967. Independent research recalculation32 PASS; provenance18 PASS. Deterministic Python replay23 artifacts: byte/SHA differences0.
Formal and candidate runs retain exact-source ZIP bundles whose individual bytes match the recorded SHA, plus EX5, preset, terminal/editor hashes, compile log, report and journal excerpt. The candidate-only snapshot callback was added after the formal run; the exact prior sources remain in its bundle/owning commit.
See `technical_discovery_implementation.md` for commands and causal definitions, and `technical_candidate_usage.md` for tester-only operation. No existing Step3 fixture/expected is edited. Unrelated Step15G dirty work is not included in these commits.

## Primary paths

- Research: `reports/backtest/runs/20260909_tstech_discovery_r2_202504/`
- Analysis: `reports/analysis/tick_shock/technical_discovery/`
- Deterministic replay: `reports/analysis/tick_shock/technical_discovery_replay/`
- Candidate tester: `reports/backtest/runs/20260909_tstech_candidate_202504/`
- EA: `mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnicalCandidate.mq5`
- Model: `mql/Include/TickShock/TickShockTechnicalModel.mqh`

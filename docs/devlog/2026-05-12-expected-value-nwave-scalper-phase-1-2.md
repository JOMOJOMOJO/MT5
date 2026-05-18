# 2026-05-12 - expected-value-nwave-scalper-phase-1-2

## Summary

- task: create the first `Strategy_01_NWave_ExpectedValue` EA scaffold focused on repeatable setup detection and R-unit logging
- EA / family: `ExpectedValue_NWave_Scalper`
- decision status: implemented Phase 1-2 for compile-ready validation, not promoted

## Changes

- added `mql/Experts/ExpectedValue_NWave_Scalper.mq5`
- implemented confirmed swing detection without current-bar pivots
- implemented simplified bearish/bullish N-wave exhaustion detection on `ContextTF` or `PatternTF`
- implemented Fibo extension and ATR expansion filters
- implemented EntryTF double-bottom/double-top detection with neckline close-break confirmation
- implemented fixed SL/TP, RR, risk-based lot sizing, virtual trade tracking, CSV logging, and chart objects
- kept `EnableTrading=false` as the default so the first validation pass records virtual entries before live execution

## Evidence Links

- code: `mql/Experts/ExpectedValue_NWave_Scalper.mq5`
- compile log: `reports/compile/ExpectedValue_NWave_Scalper.log`

## Outcome

- MetaEditor compile result: `0 errors, 0 warnings`
- no backtest acceptance claim has been made yet
- next validation should inspect signal frequency, stop distance realism, R expectancy, and symbol-specific spread assumptions on XAUUSD / USDJPY / EURUSD

## Notes

- daily loss, consecutive-loss, and max-position guards are present, but the initial intended workflow is virtual logging and R-unit review.
- the first statistical question is not win rate; it is whether the same closed-bar setup produces stable expectancy after spread and stop-distance constraints.

## 2026-05-12 Follow-up: execution-aligned diagnostics

- separated `SignalPrice` from executable `EntryPrice`; the signal remains based on closed bars, while virtual entries now use current Ask/Bid.
- changed risk sizing to use `OrderCalcProfit()` so the planned loss is calculated in account currency instead of relying only on tick value metadata.
- added `FILTER_ANY` / `FILTER_ALL`, with `FILTER_ALL` as the default for N-wave extension filters.
- added reject logging for non-executable candidates, including spread, session, daily loss, loss streak, max positions, RR, stops, lot/risk, and N-wave filter failures.
- added R-unit summary statistics and summary CSV output for virtual or live closed trades.
- added conservative same-bar virtual exit handling, defaulting to SL-first when TP and SL are both touched in the same EntryTF bar.

## 2026-05-14 Backtest: USDJPY OOS 3M Baseline

- ran `ExpectedValue_NWave_Scalper` on `USDJPY M5`, `2025.12.31` to `2026.03.30`, with `EnableTrading=false`.
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-oos-3m/`.
- closed virtual trades: `194`; win rate: `38.14%`; expectancy: `-0.0464R`; PF: `0.9250`; max consecutive losses: `11`.
- result is not promotable; this validates that the diagnostics pipeline works, but the default rule set does not yet show positive R expectancy.

## 2026-05-14 Backtest: Causal Split Diagnostics

- ran four diagnostic variants without adding strategy logic:
  - A: `MaxManagedPositions=1`, `TP=1.5R`
  - B: `MaxManagedPositions=2`, `TP=1.5R`
  - C: `MaxManagedPositions=1`, `TP=1.2R`
  - D: `MaxManagedPositions=1`, `TP=2.0R`
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-causal-splits/`.
- Run B improved expectancy to `+0.0436R` and reduced `max_positions_blocked` from `554` to `279`, so the one-position cap materially changes the observed edge.
- Run C improved expectancy to `+0.0196R`, but `rr_too_low=454` means it is not a clean TP-only comparison under `MinRR=1.2`.
- Run D degraded to `-0.1608R`, suggesting `2.0R` is too far for this initial rule set.
- no promotion decision was made; this is cause decomposition only.

## 2026-05-14 Backtest: Baseline-B Expanded Validation

- expanded Run B as Baseline-B without adding strategy logic or optimization.
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-baseline-b-expanded/`.
- USDJPY `2024.01.01` to `2026.03.30`: `2848` closed virtual trades, expectancy `-0.0371R`, PF `0.9397`, max DD `141.0338R`.
- year split:
  - 2024: expectancy `-0.0200R`
  - 2025: expectancy `-0.0753R`
  - 2026 Q1: expectancy `+0.0364R`
- cross-symbol full window:
  - EURUSD: expectancy `-0.1660R`
  - XAUUSD: expectancy `-0.0220R`
- conclusion: Baseline-B is not stable enough to promote. The short positive 2026 Q1 slice should be treated as a local regime result, not a durable Strategy_01 baseline.

## 2026-05-14 Diagnostic Enhancement: Market State Tags

- added diagnostic-only CSV fields for ContextTF EMA state, EMA slope, HTF trend state, PatternTF/EntryTF ADX buckets, DI direction, ATR percentile buckets, setup quality, trend alignment, open-position context, duplicate setup flags, and MFE follow-through flags.
- preserved the existing entry logic, SL/TP logic, risk sizing, session behavior, and virtual trade rules.
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- reran Baseline-B on `USDJPY M5`, `2024.01.01` to `2026.03.30`, with Magic `2026051450`.
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-market-state-diagnostics-usdjpy-full/`.
- headline result remained unchanged: `2848` closed virtual trades, expectancy `-0.0371R`, PF `0.9397`.
- first diagnostic readout:
  - HTF flat bucket was positive (`+0.2151R`) but small (`72` trades).
  - CounterTrend was slightly positive (`+0.0099R`) over `1000` trades, while TrendFollow was materially negative (`-0.0923R`).
  - EntryOpenCount `1` remained worse (`-0.0500R`) than EntryOpenCount `0` (`-0.0216R`), confirming that the second position is not a long-window edge by itself.
  - `718` loss trades reached at least `0.5R` MFE before loss, and `259` reached at least `1.0R` before loss.
- no filter promotion was made; these are candidate explanations for later controlled tests.

## 2026-05-14 Diagnostic Enhancement: Exit Simulation Modes

- added `ExitSimulationMode` values for fixed R, BE at `0.5R` / `0.8R` / `1.0R`, partial 50% at `0.5R` / `1.0R`, fixed `1.2R`, and fixed `1.5R`.
- implementation is virtual-only: real order placement and live position management were not changed.
- the EA now writes a separate `*_exit_simulation.csv` so each accepted virtual entry can be evaluated under all exit modes without changing the entry stream.
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-exit-simulation-usdjpy-full/`.
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- MaxPos2 all-trade result:
  - `EXIT_FIXED_R_ONLY`: `-0.0371R`, PF `0.9397`
  - `EXIT_BE_AT_10R`: `-0.0778R`, PF `0.8524`
  - `EXIT_PARTIAL_50_AT_05R_REST_15R`: `-0.0448R`, PF `0.8959`
  - `EXIT_TP_12R_FIXED`: `-0.0468R`, PF `0.9175`
- MaxPos2 focus candidates:
  - `EntryOpenCount=0 + CounterTrend + BE_AT_10R`: `466` trades, `+0.0030R`, PF `1.0061`
  - `EntryOpenCount=0 + CounterTrend + PatternADX=middle + BE_AT_10R`: `172` trades, `+0.0724R`, PF `1.1465`
  - `EntryOpenCount=0 + CounterTrend + PatternADX=middle + BreakStrength=high + BE_AT_10R`: `128` trades, `+0.1052R`, PF `1.2137`
- important caution: for those same focused candidate slices, fixed `1.5R` remained better than BE_AT_10R in this simulation, so BE_AT_10R is not promoted.

## 2026-05-14 Strategy_01B: Tag Filter Validation

- added virtual-only diagnostic tag filters to `ExpectedValue_NWave_Scalper`:
  - trend alignment: any / countertrend / trend-follow / mixed
  - PatternTF ADX bucket: any / low / middle / high
  - break candle strength bucket: any / low / middle / high
  - entry open count cap
- the filters are applied only when `EnableTrading=false`; live-order behavior is intentionally unchanged.
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-strategy01b-usdjpy-filter-presets/`.
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- USDJPY `2024.01.01` to `2026.03.30`, `M5`, `H4/M15/M5`, `MaxManagedPositions=2`, fixed `1.5R`:
  - Preset C (`CounterTrend + PatternADX=middle`): `801` trades, expectancy `+0.0673R`, PF `1.1175`, max DD `23.0059R`, positive quarters `5/9`.
  - Preset H (`C + EntryOpenCount<=0`): `633` trades, expectancy `+0.0623R`, PF `1.1084`, max DD `20.0008R`, positive quarters `7/9`.
  - Preset J (`H + BreakStrength=high`): `532` trades, expectancy `+0.0853R`, PF `1.1508`, max DD `21.4969R`, positive quarters `8/9`.
- Preset C remains the broad validation candidate. Preset J is the stricter candidate with the best full-window expectancy, but lower trade count.
- EURUSD/XAUUSD reference runs were attempted, but no complete summary CSV was produced within the per-run timeout, so they were not used as evidence.
- no promotion was made; this is a Strategy_01B candidate filter validation only.

## 2026-05-14 Strategy_01B: Direction Filter Independent Validation

- added a virtual-only `DirectionFilter`:
  - any
  - long only
  - short only
- the filter is applied only when `EnableTrading=false`; real order placement and live trade management remain unchanged.
- reran `USDJPY M5` as independent MT5 Strategy Tester runs, not calendar splits from a single full-window run:
  - full window
  - 2024, 2025, 2026 Q1
  - 2024 Q1 through 2026 Q1
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-strategy01b-direction-independent/`.
- all `117` requested summary runs completed; `missing_runs.csv` reports `all_summaries_present`.
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- full-window readout:
  - C Any: `801` trades, `+0.0673R`, PF `1.1175`, MaxDD `23.0059R`, positive years `2/3`, positive quarters `5/9`.
  - C ShortOnly: `505` trades, `+0.1484R`, PF `1.2744`, MaxDD `16.0048R`, positive years `3/3`, positive quarters `9/9`.
  - H Any: `633` trades, `+0.0623R`, PF `1.1084`, MaxDD `20.0008R`, positive years `3/3`, positive quarters `7/9`.
  - H ShortOnly: `406` trades, `+0.1267R`, PF `1.2307`, MaxDD `16.0024R`, positive years `3/3`, positive quarters `7/9`.
  - J Any: `532` trades, `+0.0853R`, PF `1.1508`, MaxDD `21.4969R`, positive years `3/3`, positive quarters `8/9`.
  - J ShortOnly: `340` trades, `+0.1467R`, PF `1.2711`, MaxDD `11.5070R`, positive years `3/3`, positive quarters `8/9`.
- conclusion: ShortOnly materially improves all C/H/J candidates in this USDJPY validation. LongOnly remains weak and is not supported as-is.
- no demo/live promotion was made; the next decision should compare broad C ShortOnly versus stricter J ShortOnly, with month clustering and forward-demo readiness reviewed separately.

## 2026-05-14 Strategy_01B: Frozen StrategyMode Regression

- added `SelectedStrategyMode`:
  - `STRATEGY_01_ORIGINAL`
  - `STRATEGY_01B_C_SHORT`
  - `STRATEGY_01B_J_SHORT`
- default remains safe: `EnableTrading=false` and `SelectedStrategyMode=STRATEGY_01_ORIGINAL`.
- Strategy_01B modes now apply the frozen candidate filters in the shared execution guard, so both virtual and live-order paths pass the same strategy gate:
  - C Short: short only, `CounterTrend`, PatternTF ADX bucket `middle`, fixed internal `1.5R`.
  - J Short: C Short plus break strength `high` and `EntryOpenCount <= 0`.
- added risk controls for forward-readiness:
  - total open risk cap
  - daily/weekly/monthly loss in R
  - max drawdown in R stop
  - equity-curve guard switch
  - minimum bars between entries
  - optional one-position cap for Strategy_01B modes
- default per-trade risk was reduced to `0.5%`; Strategy_01B one-position cap defaults to enabled for safety.
- R-unit daily/weekly/monthly guards default to enabled through `UseEquityCurveGuard=true`; the drawdown-R stop remains opt-in until a concrete threshold is selected.
- evidence is stored under `reports/backtest/runs/2026-05-14-expected-value-nwave-strategy01b-strategy-mode-regression/`.
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- regression presets disabled the new risk-only guards so the test isolates whether `SelectedStrategyMode` reproduces the prior diagnostic-filter candidates.
- full-window equivalence:
  - C Short mode: `505` trades, expectancy `+0.1484R`, PF `1.2744`, MaxDD `16.0048R`; delta versus prior DirectionFilter run was zero.
  - J Short mode: `340` trades, expectancy `+0.1467R`, PF `1.2711`, MaxDD `11.5070R`; delta versus prior DirectionFilter run was zero.
- independent period confirmation:
  - C Short mode: positive years `3/3`, positive quarters `9/9`.
  - J Short mode: positive years `3/3`, positive quarters `8/9`.
- ran a Strategy Tester smoke with `EnableTrading=true` for J Short `2026Q1`; simulated live-order path completed with `30` closed trades, confirming the order path does not fail. This is not a virtual expectancy comparison because actual tester fills differ from virtual logging.
- no demo/live promotion was made; next work should be forward-demo preparation and operational risk settings, not additional curve-fit filters.

## 2026-05-15 Strategy_01B: Forward Demo Preparation

- tightened live/virtual explainability for forward demo:
  - added explicit `equity_curve_guard_blocked` fallback if a generic equity-curve guard failure ever occurs without a more specific R-period reason.
  - confirmed existing live safety reject reasons: `live_order_send_failed`, `live_position_tracking_failed`, `live_sl_tp_invalid`, and `live_lot_invalid`.
- recompiled `ExpectedValue_NWave_Scalper.mq5`; `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- ran risk guard ON/OFF regression for `USDJPY M5`, `H4/M15/M5`, fixed internal `1.5R`, `EnableTrading=false`:
  - evidence: `reports/backtest/runs/2026-05-15-expected-value-nwave-strategy01b-forward-demo-prep-risk-guards/summary.md`
  - C Short guard off: `505` trades, expectancy `+0.1484R`, PF `1.2744`, MaxDD `16.0048R`.
  - C Short guard on conservative: `377` trades, expectancy `+0.1471R`, PF `1.2718`, MaxDD `15.4988R`.
  - C Short guard on very conservative: `159` trades, expectancy `+0.0218R`, PF `1.0368`, MaxDD `15.5039R`; this is too restrictive for C as first demo setting.
  - J Short guard off: `340` trades, expectancy `+0.1467R`, PF `1.2711`, MaxDD `11.5070R`.
  - J Short guard on conservative: `327` trades, expectancy `+0.1541R`, PF `1.2863`, MaxDD `9.5070R`.
  - J Short guard on very conservative: `318` trades, expectancy `+0.1553R`, PF `1.2889`, MaxDD `9.0000R`.
- ran `EnableTrading=true` smoke for C/J Short over `2026Q1`, `2025Q4`, and `2025` using the very conservative risk guard:
  - evidence: `reports/backtest/runs/2026-05-15-expected-value-nwave-strategy01b-forward-demo-prep-live-smoke/summary.md`
  - all 6 smoke runs completed.
  - diagnostics recorded no `live_order_send_failed`, `live_position_tracking_failed`, `live_sl_tp_invalid`, or `live_lot_invalid`.
  - this is execution-path safety evidence, not a direct virtual-expectancy comparison.
- created demo presets:
  - `reports/presets/ExpectedValue_NWave_C_SHORT_demo_conservative.set`
  - `reports/presets/ExpectedValue_NWave_J_SHORT_demo_conservative.set`
  - `reports/presets/ExpectedValue_NWave_J_SHORT_demo_very_conservative.set`
- created forward demo operations docs:
  - `reports/forward_demo/Strategy_01B_forward_demo_runbook.md`
  - `reports/forward_demo/Strategy_01B_risk_settings.md`
  - `reports/forward_demo/Strategy_01B_promotion_checklist.md`
- decision: `J_SHORT` is the first demo candidate. It preserved expectancy under strict risk guards while reducing drawdown and avoided the large trade-count collapse seen in C Short under the very conservative full-window guard.
- promotion stance: demo forward may proceed after manual signal-only confirmation; live remains explicitly not approved.

## 2026-05-15 Strategy_01B: Forward Demo Monitoring

- added forward-demo monitoring without changing the frozen Strategy_01B entry rules, TP/SL calculation, or existing risk-guard decision logic.
- added `InpBlockUnsafeForwardDemoSettings=true`.
  - In signal-only mode, unsafe settings produce preflight warnings but validation can continue.
  - In `EnableTrading=true`, unsafe forward-demo settings block new orders with `RejectReason=unsafe_forward_demo_setting_blocked`.
- added preflight CSV output with account, broker, symbol, timeframe, StrategyMode, risk settings, MagicNumber, and broker symbol properties.
- added daily summary CSV output with signals, live entries, closed trades, R results, max daily DD, reject reason top 3, live error counts, and stop condition fields.
- added stop-condition logging for daily/weekly/monthly R loss, live tracking/SLTP/lot/order failures, missing SL/TP order, unexpected symbol, unsafe settings, and CSV output failure.
- evidence is stored under `reports/backtest/runs/2026-05-15-expected-value-nwave-strategy01b-forward-demo-monitoring/`.
- sample CSVs are stored under `reports/forward_demo/`:
  - `preflight_sample_safe_j_short.csv`
  - `preflight_sample_unsafe_block.csv`
  - `daily_summary_sample_safe_j_short.csv`
  - `daily_summary_sample_unsafe_block.csv`
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- minimal regression:
  - safe signal-only J Short 2026Q1: `30` virtual trades, expectancy `+0.3328R`, PF `1.7132`, MaxDD `4.0000R`.
  - safe `EnableTrading=true` smoke J Short 2026Q1: `29` tester live-path trades, no live order/tracking/SLTP/lot errors.
  - unsafe live setting test: preflight `BLOCK`, `0` closed trades, `0` live entries, `50` `unsafe_forward_demo_setting_blocked` rejects.
  - J Short virtual regression with prior very-conservative 2026Q1 settings remained `30` trades, expectancy `+0.3328R`, PF `1.7132`, MaxDD `4.0000R`.
- updated forward-demo runbook, risk settings, and promotion checklist with preflight and daily-summary review steps.
- decision remains unchanged: proceed only to forward demo with `J_SHORT` conservative preset after manual signal-only confirmation; live remains explicitly not approved.

## 2026-05-15 Strategy_01B: Artifact Integrity Check

- verified that the forward-demo monitoring implementation is present in `mql/Experts/ExpectedValue_NWave_Scalper.mq5`.
- evidence is stored under `reports/backtest/runs/2026-05-15-expected-value-nwave-strategy01b-artifact-integrity/artifact_integrity_summary.md`.
- grep confirmed the expected implementation markers:
  - `InpBlockUnsafeForwardDemoSettings`
  - `unsafe_forward_demo_setting_blocked`
  - `WriteForwardDemoPreflightCSV`
  - `WriteDailySummaryCSV`
  - `stop_condition_triggered`
  - `stop_reason`
  - `csv_log_output_failed`
  - `missing_sl_tp_order`
- forward-demo preset check confirmed `ExpectedValue_NWave_J_SHORT_demo_conservative.set` uses `EnableTrading=false`, `SelectedStrategyMode=2`, `RiskPercent=0.25`, `MaxTotalOpenRiskPercent=0.25`, `MaxSpreadPoints=30.0`, `AllowOnlyOnePositionForStrategy01B=true`, `UseEquityCurveGuard=true`, and `InpBlockUnsafeForwardDemoSettings=true`.
- compile evidence: `reports/compile/ExpectedValue_NWave_Scalper.log` reports `0 errors, 0 warnings`.
- reran four integrity tests:
  - safe signal-only J Short 2026Q1: `30` virtual trades, expectancy `+0.3328R`, PF `1.7132`, MaxDD `4.0000R`.
  - safe `EnableTrading=true` smoke J Short 2026Q1: `29` live-path entries, live error count `0`.
  - unsafe setting block: preflight `BLOCK`, `0` live entries, `0` closed trades, `50` `unsafe_forward_demo_setting_blocked` rejects.
  - J Short virtual regression: `30` trades, expectancy `+0.3328R`, PF `1.7132`, MaxDD `4.0000R`.
- no strategy improvement was made in this integrity pass; entry conditions, C/J StrategyMode filters, TP/SL calculation, and existing risk-guard decision logic were not changed.
- decision remains unchanged: `J_SHORT` conservative preset can proceed to forward demo after manual signal-only review; live remains explicitly not approved.

## 2026-05-15 Strategy_01B_J_SHORT: 2025 IS Parameter Validation and 2026 Jan-Apr OOS

- ran a bounded robustness grid for `STRATEGY_01B_J_SHORT` on `USDJPY / M5`, using `2025.01.01-2025.12.31` as in-sample only.
- held out `2026.01.01-2026.04.30` until after parameter selection.
- did not change EA source behavior; TP/SL calculation, fixed `1.5R` exit, lot calculation, and existing risk guard decision logic were unchanged.
- grid size: `45` combinations across:
  - `DoubleTopBottomToleranceATR`: `0.20`, `0.25`, `0.30`
  - `NecklineBreakBufferATR`: `0.03`, `0.05`, `0.07`
  - `ADXLowThreshold/ADXHighThreshold`: `18/28`, `18/30`, `20/30`, `20/32`, `22/32`
- selected from 2025 IS only:
  - `DoubleTopBottomToleranceATR=0.25`
  - `NecklineBreakBufferATR=0.07`
  - `ADXLowThreshold=20.0`
  - `ADXHighThreshold=30.0`
- selected IS result: `113` trades, expectancy `+0.3272R`, PF `1.6976`, MaxDD `9.0000R`, all four 2025 quarters positive.
- OOS virtual result for `2026.01.01-2026.04.30`: `41` trades, expectancy `+0.0973R`, PF `1.1735`, MaxDD `8.0046R`, AvgLossR `-1.0000R`, live error reject columns `0`.
- `EnableTrading=true` tester smoke over the same OOS window recorded no live order/tracking/SLTP/lot errors, but realized tester R was weaker: expectancy `-0.0849R`, PF `0.8666`. This is treated as execution-friction caution, not as virtual edge evidence.
- evidence:
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/optimization_2025_summary.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/forward_2026_jan_apr_summary.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/selected_parameter_set.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/robustness_analysis.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/rejected_parameter_sets.md`
- created selected preset: `reports/presets/ExpectedValue_NWave_J_SHORT_demo_conservative_2025IS_selected.set`.
- decision: OOS virtual passes the stated thresholds, so the selected preset can proceed to forward-demo validation only. Live/main-account operation remains explicitly not approved.

## 2026-05-15 Strategy_01B_J_SHORT: Virtual vs EnableTrading=true OOS Diff

- compared the selected J Short preset over `2026.01.01-2026.04.30` between:
  - virtual diagnostic path, `EnableTrading=false`, magic `2026053201`
  - tester order path, `EnableTrading=true`, magic `2026053202`
- matched trades by `SetupId + EntryTime + Direction`.
- planned trade parity was confirmed for the `40` matched entries:
  - entry price differences: `0`
  - SL differences: `0`
  - TP differences: `0`
  - RiskPoints differences: `0`
- the deterioration came from exit execution, not from different entry conditions:
  - virtual: `41` trades, expectancy `+0.0973R`, PF `1.1735`, TotalR `+3.9899R`
  - live smoke: `40` trades, expectancy `-0.0849R`, PF `0.8666`, TotalR `-3.3979R`
  - total R degradation: `-7.3879R`
- main source:
  - `3` trades were virtual winners but live-smoke losers, costing `-7.5403R`.
  - one virtual loser was not entered live due `entry_open_count_filter_failed`, improving live by `+1.0000R`.
- diagnosis:
  - virtual closed-bar exit uses Bid-side `iHigh/iLow`, while short live exits are Ask-triggered.
  - virtual MFE/MAE can record short MAE below `-1R` while virtual still closes the trade as TP, so the current virtual short exit model is not execution-equivalent.
- evidence:
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/virtual_vs_live_oos_2026_jan_apr_diff_summary.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/virtual_vs_live_trade_match.csv`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/monthly_virtual_vs_live_diff.csv`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/execution_friction_analysis.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-2025-is-optimization/next_action_recommendation.md`
- decision update:
  - signal-only forward demo can continue.
  - do not switch to `EnableTrading=true` demo until execution-parity diagnostics or virtual short exit handling are corrected and the same OOS comparison is rerun.
  - live/main-account operation remains explicitly not approved.

## 2026-05-15 Strategy_01B_J_SHORT: Live-Path IS/OOS Selection

- switched the promotion evidence from virtual diagnostics to `EnableTrading=true` tester realized R.
- did not change EA source behavior; Strategy_01B_J_SHORT entry filters, TP/SL calculation, fixed `1.5R` exit, lot calculation, and existing risk-guard decision logic were unchanged.
- reran the existing `45`-combination grid on `USDJPY / M5` over `2025.01.01-2025.12.31` with `EnableTrading=true`.
- 2025 IS live-path results:
  - `34/45` combinations passed the IS gate.
  - top IS candidate was `g024` with expectancy `+0.2400R`, PF `1.4651`, MaxDD `9.1783R`, and all four quarters positive.
- fixed the top 5 IS candidates and applied them to `2026.01.01-2026.04.30` OOS, without using OOS for selection.
- only `g039` passed the OOS live-path gate:
  - parameters: `DoubleTopBottomToleranceATR=0.20`, `NecklineBreakBufferATR=0.07`, `ADXLowThreshold=22.0`, `ADXHighThreshold=32.0`
  - 2025 IS: `92` trades, expectancy `+0.2014R`, PF `1.3797`, MaxDD `11.5745R`
  - 2026 Jan-Apr OOS: `38` trades, expectancy `+0.1729R`, PF `1.3249`, MaxDD `5.0907R`, live error count `0`
- the 2025 IS rank-1 candidate `g024` failed OOS with expectancy `-0.0849R`, confirming that IS rank alone is not sufficient.
- evidence:
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/livepath_2025_grid_metrics.csv`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/livepath_2025_optimization_summary.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/livepath_2026_jan_apr_oos_summary.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/livepath_selected_parameter_set.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/livepath_rejected_parameter_sets.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/livepath_robustness_analysis.md`
  - `reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/production_readiness_decision.md`
- decision:
  - virtual results remain useful for signal discovery and diagnostics, but are no longer accepted for demo/live promotion.
  - `g039` may proceed only to controlled demo `EnableTrading=true` validation after preflight.
  - production and small-live remain explicitly not approved.


## 2026-05-15 g039 production-ops preparation

- Added DD% Soft/Hard/Emergency guard inputs and stop reasons to `mql/Experts/ExpectedValue_NWave_Scalper.mq5` without changing Strategy_01B entry conditions, TP/SL calculation, fixed 1.5R exit, or lot sizing.
- Added deal-level live-path logging for actual entry/exit deals, slippage, commission, swap, realized R, and drawdown.
- Compile evidence: `reports/compile/ExpectedValue_NWave_Scalper_g039_production_ops.log` (0 errors / 0 warnings).
- MT5 live-path evidence and reports: `reports/backtest/runs/2026-05-15-expected-value-nwave-g039-production-ops/summary.md`.
- Decision: g039 can proceed to controlled demo, but small live and full production remain blocked pending 30-50 demo live-path trades and deal-level review.

## 2026-05-15 g039 controlled-demo operations

- Created controlled demo preset: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_controlled_demo.set` with `EnableTrading=true`, `RiskPercent=0.10`, `MaxTotalOpenRiskPercent=0.10`, DD% guards on, and non-demo account block on.
- Added `InpBlockNonDemoAccountForForwardDemo` and preflight account mode fields to `mql/Experts/ExpectedValue_NWave_Scalper.mq5`; strategy logic and g039 parameters were not changed.
- Expanded daily summary fields for realized money, PF, daily DD%, weekly/monthly guard counts, and DD% guard counts.
- Controlled demo operational artifacts are under `reports/forward_demo/`, including runbook, daily checklist, status summary, sample preflight, and sample daily report.
- Risk decision: controlled demo approved; small live and full production remain blocked. A 100 USD small-capital exception is not automated and requires broker minimum-lot risk confirmation first.

## 2026-05-18 g039 USD small-capital challenge mode

- Added USD account small-capital challenge controls to `mql/Experts/ExpectedValue_NWave_Scalper.mq5` without changing Strategy_01B_J_SHORT entry logic, C/J filters, TP/SL, fixed 1.5R exit, or g039 parameters.
- New controls include equity/balance-based USD risk tiers, min-lot override with effective-risk cap, margin sufficiency logging, challenge DD guards, and ruin status fields.
- Compile evidence: `reports/compile/ExpectedValue_NWave_Scalper_usd_small_capital_compile.log` (0 errors / 0 warnings).
- Created challenge demo preset: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd_small_capital_challenge_demo.set`.
- Ran live-path tester matrix for 100 / 500 / 1000 / 10000 USD deposits over 2025, 2026 Jan-Apr, and 2024-2026 reference windows:
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd-small-capital/summary.md`
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd-small-capital/usd_small_capital_metrics.csv`
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd-small-capital/usd_small_capital_lot_feasibility.md`
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd-small-capital/usd_small_capital_risk_ladder_comparison.md`
- Operational finding:
  - 0.01 lot is technically possible in the tester for 100 USD, but the 10/5/1 ladder repeatedly fails from margin insufficiency.
  - The safer 5/2/1 ladder is the preferred demo candidate; 1000 USD is the first account size with clean 2025 and 2026 Jan-Apr runs, though the 2024-2026 reference remains too weak for live approval.
- Decision: small-capital challenge demo can proceed only as high-risk demo evidence gathering. Small live high-risk challenge and full production remain explicitly not approved.
- Additional practical preset from the evidence: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd_small_capital_challenge_demo_safer.set` with 5/2/1 tiers.

## 2026-05-18 g039 USD100 fixed-min-lot challenge validation

- Added `InpUseUsd100ChallengeMode` to `mql/Experts/ExpectedValue_NWave_Scalper.mq5` as a separate 100 USD challenge sizing layer.
- Strategy_01B_J_SHORT g039 entry logic, C/J filters, TP/SL, fixed 1.5R exit, and g039 parameters were not changed.
- New USD100 controls enforce USD account assumption, fixed min-lot operation, effective-risk warning/block thresholds, margin sufficiency block, and USD100 DD stop reasons.
- Compile evidence: `reports/compile/ExpectedValue_NWave_Scalper_usd100_challenge_compile.log` (0 errors / 0 warnings).
- Created final demo preset: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd100_minlot_challenge_demo.set`.
- Ran 100 USD live-path tester comparison for fixed 0.01 lot, existing 5/2/1 ladder, and hybrid USD100 over 2025, 2026 Jan-Apr, and 2024-2026 reference:
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-challenge/summary.md`
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-challenge/usd100_challenge_metrics.csv`
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-challenge/usd100_minlot_backtest_summary.md`
  - `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-challenge/usd100_challenge_real_money_decision.md`
- Result:
  - fixed 0.01 lot had no margin rejects, no ruin flag, and max accepted effective risk stayed under 10% in tested windows.
  - 5/2/1 ladder still produced margin rejects and repeated margin-insufficient states in non-2025 windows.
  - hybrid matched fixed 0.01 lot because equity never reached the 1000 USD transition tier.
- Decision: 100 USD demo challenge can proceed with fixed 0.01 lot. 100 USD real-money challenge is not approved until at least 30 clean demo trades. Production remains separate and not approved.

## 2026-05-18 g039 USD100 May 2026 no-trade diagnosis

- Investigated why a May 2026 MT5 backtest produced no trades.
- Found one blocked preflight with `timeframe=M1`, `preflight_status=BLOCK`, and warning `chart_timeframe_not_m5`; g039 is M5-only under forward-demo safety checks.
- Reran `2026.05.01-2026.05.18` on USDJPY M5 with the USD100 fixed-min-lot preset and `EnableTrading=true`.
- Correct M5 run had preflight `PASS` but still produced `0` closed trades; diagnostics showed 123 rejected candidates, mainly direction, trend alignment, fibo, and pattern ADX filters.
- Evidence: `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-may-check/may2026_no_trade_diagnosis.md`.

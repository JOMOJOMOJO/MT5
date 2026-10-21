# Review and successor implementation

## Completed prior control

[2022 execution parity](../q12_refactor_check_20261006/runs/20261006_224527_848c0c5f/refactored_control_2022/execution_parity.json): 76 trades, all execution/cost fields identical to research baseline, net -696.81, PF 0.71049. The refactor and observer did not cause the recent 0.40/0.41 discrepancy in this control. The difference against the older run is not fully attributed.

## Fixed in RelativeContinuation v2

| Finding | Change |
|---|---|
| Floating spread boundary rejection | Compare spread/ATR with arithmetic-only epsilon; no extra market tick allowance |
| Hard-coded FX pip convention / 36 fixed price widths | Closed signal-timeframe ATR distances; documented grid semantic change |
| Price rounded only to decimal digits | Use broker trade tick size |
| Buy stop validation used Ask distance | Validate against Bid for buy, Ask for sell; require positive SL and TP distances |
| Tick-value profit convention used for risk | `OrderCalcProfit` in account currency using side, entry and SL; margin check |
| Minimum volume rounded upward and small accounts increased risk | Skip below-minimum risk budgets; remove currency-denominated small-account override |
| CTrade bool mistaken for fill success | Validate return code, track unresolved sends, no blind retry |
| Broker filling mode not selected | Select symbol-supported fill policy |
| Daily/DD flatten delayed to new bar, cap could unlatch after recovery | Tick-level checks with persistent latches and live restart state |
| Restart reset daily trade count / partial fills counted as trades | Recover unique entry order IDs from history |
| Netting position could merge with another bucket/strategy | Block any occupied netting symbol and pending own orders |
| Shared session blocked buckets with different intended sessions | Apply each bucket's own session at decision time |
| Range short depended on long being enabled for new-bar detection | Include either flag in trigger |
| Fixed array load sizes could fail for larger configured lookbacks | Compute required window and require complete arrays |
| Weekday strings silently parsed non-numeric text as zero | Strict single-digit 0–6 validation |
| Separate chart symbol could drive wrong tick timing | Empty symbol follows chart; explicit different chart symbol rejected |
| Multi-symbol default telemetry file collision | Symbol/magic-specific default live files |

## Intentional retained conditions / limits

This remains a M15 continuation strategy with an upper-wick-heavy trigger, not a mathematical M5/M1 Wave3 strategy. The wick logic is unusual, but no evidence justifies reversing it as a bug fix. All optional inherited buckets are disabled in this study. Signal and risk changes are bundled in v2; result changes cannot be attributed solely to spread or ATR.

The zero-origin ATR grid replaces a psychological round-number grid. This is not an equivalent port. Signal ATR is shared by all buckets, including those with lower execution timeframes, explicitly avoiding ambiguous units.

Risk budget is planned price loss; gaps, fees and execution slippage can exceed it. Tick checks cannot guarantee a hard equity floor during gaps. Unresolved order outcomes deliberately block new orders until evidence resolves them. Persistent risk state is local to the terminal and strategy instance, not a cross-terminal portfolio ledger. Moving to a fresh terminal does not carry that state.

All-symbol *units* are supported; all-symbol execution/performance is not certified. Gold has not yet been tested. Session hours remain broker-specific. Live/deferred-protection/partial-fill scenarios need dedicated validation before live use.

## Evidence

- [Compile](compile.log): 0 errors / 0 warnings.
- Python tests: 35 passed, including train/validation separation, zero-month counts, cost/R separation and source safety contracts. Source contract checks are not MT5 execution tests.
- [Input mapping](parameter_migration.json), [frozen search plan](../rc_search_20261007/plan.md).
- [Prior spread diagnosis](../quality12b_spread_diagnosis_20261006/summary.md): 2024 June–November 7,800 gate calls all genuinely over 2pips; boundary fix alone cannot remove that block. Counts were gates, not qualified signals.
- MetaQuotes references: [CTrade Buy result semantics](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy), [symbol tick/stop/volume properties](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants).

Old quality12b and ThreeWave production files were not overwritten. Use `RelativeContinuation.mq5` and its new full preset for this study. No EX5 was synchronized to installed live terminals.

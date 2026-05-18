# Virtual vs Live Smoke OOS Diff Summary

Generated: 2026-05-15

## Scope
- Strategy: `STRATEGY_01B_J_SHORT`
- Preset: `ExpectedValue_NWave_J_SHORT_demo_conservative_2025IS_selected.set`
- Symbol/timeframe: USDJPY / M5
- Window: `2026.01.01` - `2026.04.30`
- Virtual run magic: `2026053201`
- EnableTrading=true smoke magic: `2026053202`

No parameter optimization or strategy improvement was performed. EA source entry conditions, C/J conditions, TP/SL calculation, fixed `1.5R` exit, lot calculation, and existing risk guard decision logic were not changed.

## Headline
The live-smoke deterioration is not caused by different planned entries, SL, TP, or risk points. For the `40` matched live/virtual entries:
- `EntryPriceDiff != 0`: `0`
- `SLDiff != 0`: `0`
- `TPDiff != 0`: `0`
- `RiskPointsDiff != 0`: `0`

The main difference is exit execution. Three virtual winners became live-smoke losers, accounting for `-7.540311R`, more than the total virtual-to-live degradation.

## Overall Metrics
|Metric|Virtual OOS|Live Smoke|Live - Virtual|
|---|---:|---:|---:|
|Closed trades|41|40|-1|
|Wins|18|15|-3|
|Losses|23|25|+2|
|Win rate|43.9024%|37.5000%|-6.4024 pp|
|AvgWinR|1.499440|1.472009|-0.027431|
|AvgLossR|-1.000000|-1.019123|-0.019123|
|ExpectancyR|0.097315|-0.084949|-0.182264|
|PF|1.173475|0.866633|-0.306843|
|MaxDD_R|8.004638|11.726668|+3.722030|
|Max consecutive losses|7|7|0|
|TotalR|3.989926|-3.397948|-7.387874|

## Trade Matching Classification
|Classification|Count|Total R Diff|Avg R Diff|Interpretation|
|---|---:|---:|---:|---|
|same_outcome_near_equal|31|-0.171517|-0.005533|Minor execution/friction noise.|
|same_outcome_material_r_diff|6|-0.676046|-0.112674|Same win/loss direction, but live R worse.|
|virtual_win_live_loss|3|-7.540311|-2.513437|Primary damage source.|
|virtual_entry_live_not_entered|1|+1.000000|+1.000000|Live missed one virtual loser because a previous live position was still open.|
|live_only_entry|0|0|0|No extra live-only trades.|

Largest adverse mismatches:
|Month|SetupId|EntryTime|Virtual|Live|R Diff|Virtual Exit|Live Exit|Notes|
|---|---|---|---:|---:|---:|---|---|---|
|2026-01|`SHORT_1769076600_158.722`|2026.01.22 12:35:00|+1.500000|-1.031363|-2.531363|2026.01.22 17:05|2026.01.22 15:00|Virtual MFE and MAE both crossed major thresholds; live SL first.|
|2026-03|`SHORT_1773893100_159.671`|2026.03.19 06:45:01|+1.496689|-1.006512|-2.503201|2026.03.19 10:05|2026.03.19 09:50|Virtual MAE reached below -1R but virtual still closed TP.|
|2026-04|`SHORT_1776862800_159.306`|2026.04.22 13:35:00|+1.505747|-1.000000|-2.505747|2026.04.22 15:25|2026.04.22 15:50|Short TP likely counted on Bid low in virtual while live sell close required Ask.|

## Monthly Diff
|Month|Virtual Trades|Live Trades|Virtual R|Live R|R Diff|Virtual W/L|Live W/L|Main Difference|
|---|---:|---:|---:|---:|---:|---|---|---|
|2026-01|10|10|+2.492325|-0.189173|-2.681498|5/5|4/6|One virtual win became live loss.|
|2026-02|6|6|+3.996855|+3.791604|-0.205251|4/2|4/2|No result flips, only friction.|
|2026-03|15|15|-0.005002|-2.888334|-2.883333|6/9|5/10|One virtual win became live loss plus weaker same-result R.|
|2026-04|10|9|-2.494253|-4.112045|-1.617792|3/7|2/7|One virtual win became live loss; one virtual loser was skipped live.|

The March and April degradation is not from new live-only entries. It is from exit-path mismatch and live R being worse on matched trades.

## Cause Ranking
1. **Virtual short exit logic is optimistic/inconsistent versus live execution.** The virtual closed-bar exit check uses `iHigh/iLow` bar ranges, which are Bid-side OHLC in MT5. A short position's SL/TP is closed by buying at Ask. This makes short TP easier and short SL timing different in virtual than in live smoke.
2. **Virtual excursion and virtual exit are not using the same execution basis.** `UpdateVirtualTradeResults()` updates short MFE/MAE using Ask, but `UpdateVirtualTradeResultsOnClosedBar()` closes virtual trades using Bid high/low. This allowed virtual rows where `MAE_R < -1.0` but the trade still ended as a virtual TP.
3. **Tick order matters.** `ConservativeSameBarExit=true` only handles the case where the same closed bar range touches both SL and TP under the virtual bar model. It does not reproduce live tick order.
4. **Risk guard timing is secondary.** There was one missed live entry due `entry_open_count_filter_failed`, caused by the previous live position staying open longer than virtual. It skipped a virtual loser and improved live by `+1R`, so it is not the cause of deterioration.
5. **Broker stop/freeze levels are not implicated.** Preflight showed `StopsLevel=0` and `FreezeLevel=0`; no `live_sl_tp_invalid`, `live_lot_invalid`, `live_order_send_failed`, or `live_position_tracking_failed` occurred.

## Conclusion
- Signal-only forward demo can continue.
- EnableTrading=true demo auto-execution needs additional execution-parity confirmation before switching on.
- Production/live operation is not approved.

Supporting CSVs:
- `virtual_vs_live_trade_match.csv`
- `monthly_virtual_vs_live_diff.csv`

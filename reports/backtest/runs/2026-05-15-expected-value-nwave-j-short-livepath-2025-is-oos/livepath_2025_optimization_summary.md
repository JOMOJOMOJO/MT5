# Strategy_01B_J_SHORT Live Path 2025 IS Optimization Summary

Generated: 2026-05-15

## Scope
- Symbol/timeframe: USDJPY / M5
- Strategy: `STRATEGY_01B_J_SHORT`
- In-sample window: `2025.01.01` - `2025.12.31`
- Evaluation path: `EnableTrading=true` tester order path
- Exit: fixed internal `1.5R`
- Risk: `RiskPercent=0.25`, `MaxTotalOpenRiskPercent=0.25`
- Spread cap: `MaxSpreadPoints=30.0`
- Conservative same-bar exit remained enabled, but promotion scoring uses live-path realized `ProfitR`.

No EA source logic was changed. Entry rules, C/J conditions, TP/SL calculation, fixed 1.5R exit, lot calculation, and existing risk guard decision logic were not changed.

## Grid
The same 45 combinations were rerun on live path:
- `DoubleTopBottomToleranceATR`: `0.20`, `0.25`, `0.30`
- `NecklineBreakBufferATR`: `0.03`, `0.05`, `0.07`
- `ADXLowThreshold/ADXHighThreshold`: `18/28`, `18/30`, `20/30`, `20/32`, `22/32`

## Aggregate
- Total combinations: `45`
- Passed IS gate: `34 / 45`
- ExpectancyR range: `-0.157153` to `0.240004`
- PF range: `0.769034` to `1.465090`
- All top candidates had `live_order_send_failed=0`, `live_position_tracking_failed=0`, `live_sl_tp_invalid=0`, and `live_lot_invalid=0`.

## Top 2025 IS Candidates
|Rank|Run|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|TotalR|Positive Quarters|
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|1|g024 `tol0.25 neck0.07 adx20/30`|111|50.4505|1.498581|-1.041457|0.240004|1.465090|9.178333|26.640412|4|
|2|g003 `tol0.20 neck0.07 adx18/28`|94|48.9362|1.499343|-1.026411|0.209596|1.399898|10.330428|19.702048|4|
|3|g021 `tol0.20 neck0.07 adx20/30`|102|49.0196|1.500050|-1.032469|0.208962|1.396996|10.173862|21.314086|4|
|4|g039 `tol0.20 neck0.07 adx22/32`|92|48.9130|1.496489|-1.038505|0.201438|1.379684|11.574514|18.532260|3|
|5|g030 `tol0.20 neck0.07 adx20/32`|111|48.6486|1.500459|-1.037401|0.197234|1.370240|11.314105|21.892949|4|
|6|g023 `tol0.25 neck0.05 adx20/30`|113|48.6726|1.501219|-1.039411|0.197179|1.369593|10.095925|22.281238|4|
|7|g022 `tol0.25 neck0.03 adx20/30`|111|48.6486|1.501001|-1.038275|0.197048|1.369579|9.178004|21.872336|3|
|8|g006 `tol0.25 neck0.07 adx18/28`|105|48.5714|1.499713|-1.035045|0.196123|1.368438|10.322102|20.592912|4|
|9|g027 `tol0.30 neck0.07 adx20/30`|113|48.6726|1.498769|-1.048747|0.191194|1.355185|10.188786|21.604960|4|
|10|g033 `tol0.25 neck0.07 adx20/32`|126|48.4127|1.499192|-1.040342|0.189115|1.352376|11.200707|23.828450|4|

## Data Notes
- Current diagnostics provide realized `ProfitR`, including live-path deal profit plus swap plus commission through the EA's transaction handler.
- Current diagnostics do not separately export actual entry deal price, actual exit deal price, commission, swap, or slippage. Those are therefore not aggregated here.

Evidence:
- `livepath_2025_grid_metrics.csv`
- `raw/selected_g039_2026053339_diagnostics.csv`

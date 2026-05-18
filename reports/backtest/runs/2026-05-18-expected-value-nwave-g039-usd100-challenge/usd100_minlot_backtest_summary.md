# USD100 Min-Lot Backtest Summary

Test account: 100 USD / USDJPY M5 / EnableTrading=true live-path tester / g039 fixed.

## Fixed 0.01 Lot Results

|Pattern|Period|Trades|Win%|ExpR|PF|FinalUSD|Net%|MaxDD%|MaxDD_R|MinEq|EffAvg%|EffP95%|EffMax%|Lot|MarginRej|Repeated|EffBlock|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|fixed_min_lot_001|2024_2026|303|40.9241|0.0088|1.0144|148.0900|48.0900|32.7631|23.7439|72.0900|1.3565|3.3530|8.7166|0.01-0.01|0|0|0|no|
|fixed_min_lot_001|2025|98|45.9184|0.1246|1.2216|150.5000|50.5000|11.6145|15.7324|100.0000|1.2322|2.7181|7.0113|0.01-0.01|0|0|0|no|
|fixed_min_lot_001|2026_jan_apr|39|46.1538|0.1404|1.2573|121.8100|21.8100|8.1137|6.1482|98.8900|1.2217|1.8954|7.3049|0.01-0.01|0|0|0|no|

## Interpretation

Fixed 0.01 lot produced no margin insufficiency, no ruin flag, and no live-path errors across all tested windows. It stayed below the 10% warning threshold in accepted trades: max effective risk was 8.72% in the 2024-2026 reference window. The long reference window was only marginally positive in R, but balance increased because exposure remained constant while the account grew.

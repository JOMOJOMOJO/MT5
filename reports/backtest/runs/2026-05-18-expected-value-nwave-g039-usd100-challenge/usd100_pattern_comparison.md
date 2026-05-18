# USD100 Pattern Comparison

## All Patterns

|Pattern|Period|Trades|Win%|ExpR|PF|FinalUSD|Net%|MaxDD%|MaxDD_R|MinEq|EffAvg%|EffP95%|EffMax%|Lot|MarginRej|Repeated|EffBlock|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|fixed_min_lot_001|2024_2026|303|40.9241|0.0088|1.0144|148.0900|48.0900|32.7631|23.7439|72.0900|1.3565|3.3530|8.7166|0.01-0.01|0|0|0|no|
|fixed_min_lot_001|2025|98|45.9184|0.1246|1.2216|150.5000|50.5000|11.6145|15.7324|100.0000|1.2322|2.7181|7.0113|0.01-0.01|0|0|0|no|
|fixed_min_lot_001|2026_jan_apr|39|46.1538|0.1404|1.2573|121.8100|21.8100|8.1137|6.1482|98.8900|1.2217|1.8954|7.3049|0.01-0.01|0|0|0|no|
|hybrid_usd100|2024_2026|303|40.9241|0.0088|1.0144|148.0900|48.0900|32.7631|23.7439|72.0900|1.3565|3.3530|8.7166|0.01-0.01|0|0|0|no|
|hybrid_usd100|2025|98|45.9184|0.1246|1.2216|150.5000|50.5000|11.6145|15.7324|100.0000|1.2322|2.7181|7.0113|0.01-0.01|0|0|0|no|
|hybrid_usd100|2026_jan_apr|39|46.1538|0.1404|1.2573|121.8100|21.8100|8.1137|6.1482|98.8900|1.2217|1.8954|7.3049|0.01-0.01|0|0|0|no|
|safer_ladder_5_2_1_existing|2024_2026|51|45.0980|0.0949|1.1673|117.5500|17.5500|39.3323|10.5929|69.0300|4.3784|4.9428|4.9917|0.01-0.10|34|373|0|small_capital_margin_insufficient_repeated|
|safer_ladder_5_2_1_existing|2025|78|46.1538|0.1278|1.2275|125.1500|25.1500|40.5322|10.4805|100.0000|4.4791|4.9502|5.3131|0.01-0.17|11|0|0|no|
|safer_ladder_5_2_1_existing|2026_jan_apr|25|52.0000|0.2855|1.5882|137.8900|37.8900|17.6428|3.0076|95.5500|4.5408|4.8287|7.4821|0.01-0.10|7|22|0|small_capital_margin_insufficient_repeated|

## Comparison

- `fixed_min_lot_001`: best operational fit for 100 USD. No margin rejects, no repeated margin insufficiency, fixed lot remains 0.01.
- `safer_ladder_5_2_1_existing`: not acceptable for 100 USD live challenge. It can grow fast in favorable windows, but margin rejects occur and 2026 Jan-Apr plus the 2024-2026 reference hit repeated margin insufficiency.
- `hybrid_usd100`: identical to fixed 0.01 lot in these windows because equity never reached 1000 USD. This is acceptable as a future transition design but offers no difference at 100 USD.

10/5/1 ladder remains rejected from the previous small-capital run because it produced repeated margin insufficiency on 100 USD.

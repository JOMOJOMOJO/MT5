# USD100 Challenge Validation Summary

EA: `ExpectedValue_NWave_Scalper.mq5` / `STRATEGY_01B_J_SHORT` / g039. Strategy logic and g039 parameters were not changed.

Compile: `reports/compile/ExpectedValue_NWave_Scalper_usd100_challenge_compile.log` => 0 errors / 0 warnings.

Preset: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd100_minlot_challenge_demo.set`.

## Result Table

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

## Final Judgment

- 100 USD demo challenge: yes, can proceed with fixed 0.01 lot preset.
- 100 USD real-money high-risk challenge: not yet; only after 30+ demo trades with clean logs.
- Fixed 0.01 lot is the best 100 USD design among tested patterns.
- 5/2/1 ladder is not preferred for 100 USD because margin issues still appear.
- 10/5/1 ladder is rejected.
- We cannot say 100 USD will not ruin; we can only say fixed 0.01 lot did not ruin in the tested windows and stayed below 10% accepted effective risk.

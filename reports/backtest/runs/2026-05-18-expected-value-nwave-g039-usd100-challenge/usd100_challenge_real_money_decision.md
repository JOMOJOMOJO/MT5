# USD100 Challenge Real-Money Decision

## Decision

100 USD real-money operation is not approved as normal live trading or production. It can be considered only as a high-risk challenge where losing the full 100 USD is acceptable.

## Evidence

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

## Required Statements

- 100 USD real-money can be allowed only as a high-risk challenge after demo validation.
- 100 USD must be money that can be fully lost.
- 100 USD uses fixed 0.01 lot as the base design.
- 10% risk ladder is rejected because previous 100 USD testing showed repeated margin insufficiency.
- 5/2/1 ladder is also not preferred for 100 USD because this test still showed margin rejects and repeated margin insufficiency in non-2025 windows.
- Effective risk above 15% must always be blocked.
- The supplied final preset also blocks above 10% effective risk for extra safety.
- No additional deposit and no risk increase before the first 30 closed trades.
- After 30 trades, reassess ExpectancyR, PF, MaxDD%, margin insufficiency, final lot, and effective risk.

## Can We Say It Will Not Ruin?

No. The fixed 0.01 lot path did not trigger ruin in the tested windows, but a 100 USD account has very little capital buffer. The 2024-2026 reference reached 32.76% DD. This is survivable in the test, but it is not enough evidence to claim non-ruin.

## Conditional Permission

Allowed next step: 100 USD demo challenge with the final preset.

Conditional real-money challenge can be considered only if the demo produces 30+ closed trades with:

- margin insufficiency = 0
- live errors = 0
- accepted effective risk <= 10%
- no 15% hard-block events
- deal-level logging complete
- operator accepts full loss risk

Small live and production remain separate and not approved by this decision.

# Step 15G Economic Path Specification

## Frozen trial TS15G-T01

| Field | Value |
|---|---|
| development window | 2025-03-01 through 2025-04-01 |
| detector | TAIL_V1_PERSISTENT |
| decisions | 60s, 120s |
| actions | continuation, reversal |
| risk | max(0.25 * completed M5 ATR14, 4.0 * entry spread, StopsLevel * point) |
| primary RR | 1.2 |
| diagnostic RR | 1.0, 1.5, 2.0 |
| horizons | 300s, 600s, 900s from anchor |
| primary tie | SL_FIRST |
| secondary tie | AMBIGUOUS_SAME_TICK |
| TP gap | fill at target |
| SL gap | fill at first executable side quote |
| timeout | first side quote at or after horizon |
| C0 | actual Bid/Ask spread |
| C1 | C0 plus documented commission/fee |
| C2 | 1.25x spread plus documented commission/fee plus 1 tick adverse entry and exit slippage |
| formal net | unavailable if commission evidence is incomplete |
| split | expanding chronological 5-fold, episode/market-cluster grouped |
| purge/embargo | horizon / 900s minimum |
| models | elastic-net logistic; shallow gradient boosting; optional fold-local calibration |
| seed | 20260901 |

The recorder must emit one row per episode, decision, action, RR, and horizon. Every row contains causal entry/exit clocks, executable quotes, fixed risk/SL/TP, first-touch status and price, timeout quote, MFE/MAE, C0/C1/C2 R, break-even additional cost, quote/fallback integrity, feature and label hashes, and an exclusion reason. No tick-level CSV is allowed.

Primary episode classes use only RR 1.2 at each registered decision/horizon. `BOTH` is descriptive, not evidence that a trade direction was knowable ex ante.

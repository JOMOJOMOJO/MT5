# Frozen January log integrity audit

Read-only audit of three frozen runs. No tester launched. All times remain MT5 source/broker time; UTC/JST not verified. Month assigned by actual fill_at, not event_at or exit_at.

| Run | Version | Last event | Closed January | Wins / losses | Net USD | PF | Sum R | Max loss streak |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| gold_v180 | 1.80 | 2025.01.30 03:01:00 | 28 | 8 / 20 | -469.77 | 0.5055 | -9.7074 | 9 |
| gold_v190 | 1.90 | 2025.01.28 11:54:00 | 23 | 4 / 18 | -451.27 | 0.4455 | -9.4988 | 8 |
| usd_v180 | 1.80 | 2025.03.27 23:57:59 | 32 | 11 / 21 | -451.31 | 0.5816 | -9.7941 | 5 |

## Counting and censoring

- All three logs have unique fill and final EXIT per observed setup, no malformed event rows, no partial-exit events, and zero observed filled positions awaiting an EXIT at snapshot.
- Gold v1.80 ends Jan30 03:01 and gold v1.90 Jan28 11:54 without TEST_END. These are partial-January samples, not a complete month or annual backtest.
- USDJPY v1.80 has complete January and February, partial March. It stops Mar27 23:57:59 with TEST_END / CENSORED_AT_STOP reason=1.
- Cash = realized_r ? execution_initial_risk_money matches to floating-point precision. This is internal event consistency, not an independent tester-report verification.

## Native gold v1.90 ledger

- 46 unique deal tickets / 23 balanced closed positions; 207 per-position checks, 0 failures.
- Deal cash sum -451.27 USD matches final EXIT cash. Recorded commission, swap and fee each zero. This does not establish a realistic all-broker cost model.
- Entry and exit prices/volumes/setup IDs reconcile. Current SL at EXIT may have trailed; use DAYTRADE_RISK_FROZEN / FILL original SL for initial R.
- Fixed TP is absent in v1.90; observed exits include SL, opposite-W1 profit and weekend close. v1.80 is fixed RR/W1-extended TP. Do not pool them as one strategy.

## H1 interpretation

- Existing h1_direction uses the latest two confirmed H1 highs and latest two confirmed H1 lows. Both rising = up; both falling = down; otherwise RANGE. It is snapped at SIGNAL, not current end-of-chart direction.
- H1_RANGE also includes insufficient four-pivot history. H1 confirmation is delayed by two right bars. It cannot express distance to a prior H1 top, range edge, or trend exhaustion.
- In all three January samples WITH_H1 is negative. Merely blocking AGAINST_H1 would not address the observed losses. This is descriptive and small-sample.

## Overlap and execution caveats

- All 23 gold v1.90 setup IDs overlap gold v1.80. Exact fill timestamp and price match 0/23; entry price matches 3/23. Repeated setups are not an independent validation set.
- v1.90 also enables both-connected-W1 cancellation, whereas v1.80 exports the older-only connected-cancellation rule. Exit model effects are confounded with this entry-state change and fill drift.
- event_at can precede fill_at. Use actual fill_at / native DEAL_TIME_MSC for entry timing, and known_at for causal feature availability. First exported bars include warmup observations known later than their close; do not backdate availability.

## USDJPY weekend loss

- Worst January loss: LONG Fri Jan24 22:02:12 at 155.859, original SL155.763; closed Mon Jan27 00:01:00 at155.590, -2.802083R / -131.81USD. First Monday M1 open155.465 is already below SL. This demonstrates weekend-gap exposure in v1.80, which has no new 24h/weekend protection.
- Approximately 1.802R of this one loss exceeds the intended 1R price stop. Do not attribute this to partial-profit logic or an H1 alignment filter.

## Evidence

- Frozen source: ../source/{gold_v180,gold_v190,usd_v180}/
- Exact counts, month/direction/H1 groups, native reconciliation and overlap: [summary.json](summary.json).
- Current source definitions: Engine.mqh H1Direction; Wave33VisualVerifier.mq5 OnTradeTransaction. No claim that a current source check proves the precise historical binary hash.

## USDJPY monetary valuation caveat

- Config reports account USD, profit currency JPY, contract100000 and calc_mode5. For all80fills, volume ? contract ? initial price risk / logged initial risk money is exactly100 (floating-point tolerance), while quoted USDJPY is near150-160. This may reflect broker/tester symbol valuation settings; frozen logs alone do not diagnose it. Do not infer ordinary spot-FX USD sizing from these dollar figures or label it an EA arithmetic bug. R conclusions remain internally consistent.
- Profit formulas: [official MQL5 symbol properties](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants). Currency conversion metadata/native report was not captured for USDJPY.

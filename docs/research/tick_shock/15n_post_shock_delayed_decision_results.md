# Step 15N: Post-Shock Delayed Decision Results

## 結論

急変後15～120秒には、完璧な事後選択を許せば約9～10%のepisodeで
`+1.6R`を選べる余地が残っていた。一方、その余地をcheckpointまでの
因果的情報だけで取引へ変換したLightGBM policyは、全checkpointで負の
Expectancy Rだった。March開発期間から固定すべきdelayはない。

- `DELAYED_ENTRY_ORACLE_FEASIBILITY_FOUND`
- `POST_SHOCK_DIRECTION_SIGNAL_FOUND`（分類上の弱い信号。売買edgeではない）
- `POST_SHOCK_NO_TRADE_SIGNAL_FOUND`（ranking enrichmentのみ）
- `DELAYED_ENTRY_TRADE_EDGE_NOT_FOUND`
- `NO_DELAY_CANDIDATE_FOUND`
- `REGIME_INSTABILITY_CONFIRMED`
- `OOS_VALIDATION_NOT_JUSTIFIED`
- `PRODUCTION_NOT_ELIGIBLE`

## 固定した検証条件

- Source population: Step 15Lの2,696 episodeを`(symbol,t0_msc)`で固定
- Checkpoints: +15/+30/+60/+120秒
- Decision: target以後の最初の同一symbol実quote
- Entry: `max(decision_quote_msc, decision_processing_msc + submit_latency)`
  以後、かつdecision featureの最終quoteより厳密に後の最初の実quote
- ATR: decision時点で利用可能な最新completed M5 ATR14
- Geometry: TP 0.40 ATR / SL 0.25 ATR / TP `+1.6R` / SL `-1R`
- Deadline: `t0 + 900秒`
- Long entry/exit: Ask / Bid、Short entry/exit: Bid / Ask
- Models: checkpoint別LightGBM、logistic baseline、4 chronological expanding folds
- Threshold: 各foldのtraining sectionだけで決定
- 注文: なし。研究EAに`OrderCheck`/`OrderSend`はない

## Formal MT5 run

正式runは
`reports/backtest/runs/20260906_ts15n_delayed_decision_r2_202503/`。
2025-03-01～2025-04-01、EURUSD M1 driver、6 symbols、real-tick modeで実行した。

- Raw candidates: 74,415
- Statistical detector events: 21,799
- Medium-horizon episodes: 3,151
- Step 15L固定母集団との一致: 2,696、missing 0
- 固定母集団外のraw episode: 455（明示的に分析対象外）
- Fixed-population checkpoint/action rows: 10,784 / 21,568
- Formal raw checkpoint/action rows: 12,604 / 25,208
- Orders/trades: 0 / 0
- Pool capacity hit、tick drop、cursor stall、global order violation: 0
- Tester runtime: 19分12.691秒
- Tester memory: 503 MB、内部計測平均/最大: 31.331/32 MB

最初のr1 runはSL gapをrealized Rへ反映しており、事前登録した
`SL_FIRST=-1R`と不一致だったため棄却した。r2とのkey、status、decision、entry、
exit、result labelは一致し、13,181 SL行のRだけが変わった。r2のTP/SL R違反は0。

## Quote freshness

既存stale基準を再利用し、staleを削除せずstatusとして保持した。

| Checkpoint | Total | Eligible | Stale | Median lag ms | P90 | P95 | P99 | Max |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 15 | 2,696 | 1,545 | 1,151 | 372.0 | 2,295.5 | 3,558.75 | 8,593.7 | 42,020 |
| 30 | 2,696 | 1,530 | 1,166 | 391.5 | 2,401.5 | 3,837.00 | 8,449.6 | 27,020 |
| 60 | 2,696 | 1,493 | 1,203 | 403.0 | 2,437.0 | 3,860.25 | 9,148.6 | 24,993 |
| 120 | 2,696 | 1,470 | 1,226 | 425.5 | 2,456.0 | 3,807.25 | 8,671.4 | 27,384 |

このstale比率自体が、現在のglobal-watermark research dispatcherで実現可能な
checkpoint populationが限定される重要な観測結果である。

## Phase A: Oracle feasibility

OracleはContinuation、Reversal、No Tradeの結果を事後的に選ぶ非実装可能な上限である。

| Delay | Eligible episodes | Clusters | Cont TP | Rev TP | Both TP | Both SL | Timeout involved | Oracle trades | Oracle expectancy per eligible | 95% cluster CI |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 15 | 1,545 | 1,450 | 70 | 74 | 0 | 1,401 | 0 | 144 | +0.1491R | [+0.1248,+0.1729] |
| 30 | 1,530 | 1,439 | 85 | 62 | 0 | 1,383 | 0 | 147 | +0.1537R | [+0.1304,+0.1782] |
| 60 | 1,493 | 1,413 | 71 | 72 | 0 | 1,349 | 1 | 143 | +0.1532R | [+0.1297,+0.1778] |
| 120 | 1,470 | 1,397 | 80 | 68 | 0 | 1,321 | 1 | 148 | +0.1611R | [+0.1353,+0.1863] |

各checkpointには予測対象となり得る余地が残るため、事前登録どおりPhase Bへ進めた。
ただし約90%がBoth SLであり、Oracle値はNo Tradeを事後選択する上限にすぎない。

## Phase B: causal prediction

No-symbol LightGBMのOOF分類診断は、AP 0.1598～0.2520、AUC
0.8787～0.9228だった。分類上のrank signalはあるが、training-only thresholdを
validationへ固定したpolicyは次のとおり全て負だった。

| Delay | Trades | TP | SL | TIMEOUT | Expectancy R | Total R | PF | Positive folds | 95% cluster CI |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 15 | 28 | 5 | 23 | 0 | -0.5357 | -15.0 | 0.348 | 0/4 | [-0.9071,-0.1643] |
| 30 | 52 | 6 | 46 | 0 | -0.7000 | -36.4 | 0.209 | 0/4 | [-0.9000,-0.4500] |
| 60 | 31 | 4 | 27 | 0 | -0.6645 | -20.6 | 0.237 | 1/4 | [-0.9161,-0.3290] |
| 120 | 30 | 10 | 20 | 0 | -0.1333 | -4.0 | 0.800 | 2/4 | [-0.5667,+0.3000] |

0.02/0.05/0.10Rのcommission sensitivityでは全結果がさらに悪化する。
Tester observed commissionは0だが、live Vantage commissionは未確認である。

Oracle-tradeable OOF episodeでのaction方向正解率は15/30/60/120秒で
54.5%/41.9%/52.4%/52.6%。+120秒の見かけ上良い平均も2 positive foldsのみで、
CIが0を跨ぎ、最終foldは再び負である。delay候補として固定できない。

## Baseline比較

| Metric | Step 15M t0 OOF | +15s | +30s | +60s | +120s |
|---|---:|---:|---:|---:|---:|
| Source/eligible episodes | 1,620 OOF | 1,545 | 1,530 | 1,493 | 1,470 |
| Oracle tradeable | N/A | 144 | 147 | 143 | 148 |
| Both-SL rate | N/A | 90.68% | 90.39% | 90.35% | 89.86% |
| Oracle expectancy | N/A | +0.1491 | +0.1537 | +0.1532 | +0.1611 |
| Model AP | 0.0997 | 0.1640 | 0.1711 | 0.1598 | 0.2520 |
| Selected trades | 25 | 28 | 52 | 31 | 30 |
| TP / SL / TIMEOUT | 4/21/0 | 5/23/0 | 6/46/0 | 4/27/0 | 10/20/0 |
| Expectancy R | -0.5840 | -0.5357 | -0.7000 | -0.6645 | -0.1333 |
| PF | N/A | 0.348 | 0.209 | 0.237 | 0.800 |
| Positive folds | 0/4 | 0/4 | 0/4 | 1/4 | 2/4 |

Step 15MとStep 15Nではentry時刻とeligible母集団が異なるため、APや損益の単純な
優劣比較ではなく、待機で情報が増えても売買期待値へ変換できなかったことを読む。

Always Continuation/Always Reversal/50-50 theoretical expectationも全delayで
約-0.86R～-0.89R。Oracle directionで全件tradeしても約-0.74R～-0.76Rであり、
No Trade選別が不可欠である。

## Symbol、session、regime

symbol identityを含むLightGBMはAPを一部改善したが、経済的policyは改善していない。
選択tradeはUSDJPYへ強く偏り、+120秒では30件全てUSDJPYだった。それでも
Expectancyは-0.1333R、2/4 positive folds、CIは0を跨ぐ。したがって
`USDJPY_DELAYED_ENTRY_EDGE_CANDIDATE`ではない。

fold/week/session別結果はそれぞれ
`checkpoint_fold_performance.csv`、`checkpoint_weekly_performance.csv`、
`checkpoint_session_performance.csv`に保存した。March後半まで安定した正のedgeはない。

## Feature interpretation

gain、permutation、LightGBM `pred_contrib`によるSHAP summaryを保存した。
全checkpointで上位は主に`decision_spread_atr`、`spread_atr_t0`、`atr14_m5`。
一部にacceleration、path contraction、activity decayが現れるが、shock後の
price-formation featureがspread/ATRを一貫して置き換えたとは言えない。
importanceは全データfitのdescriptive evidenceであり、validation成績ではない。

## QAと再現性

- Causal/population/split/order QA: 14/14 PASS
- Independent oracle/policy recalculation: 4/4 PASS
- Deterministic analysis rerun: 23/23 CSV SHA一致
- episode overlap / market-cluster overlap / chronology violation: 0/0/0
- decision before target / entry before target / entry not after feature / future feature: 0
- TP `+1.6R` / SL `-1R`違反: 0/0
- actual orders/trades: 0/0

GBPUSDでは30,187分中179分（0.593%）にreal-tick discard/generated fallbackの
tester warningがある。interval mapを取得できないため、primary推論ではGBPUSDを
除外して解釈する。他symbolはdiscard warning非観測であり、完全なreal tick保証とは
表現しない。

## データ量

研究EAはtick CSVも1秒CSVも出力しない。各active episodeが保持するのは最大121個の
1秒集計bucketで、per-symbol active poolは8。CSVはepisode×checkpointおよび
episode×checkpoint×actionのevent-level行だけである。これにより長期化時の概算は
固定母集団2,696/月ならcheckpoint約10,784行、action約21,568行/月で線形増加する。

## 最終判断

「情報が十分増え、値幅も残る時間帯」はOracle上は4 checkpoint全てに存在したが、
現在のcausal features/model/threshold ruleではいずれも正の期待値へ変換できない。
+120秒をMarchだけで選ぶのはselection biasになる。長期OOSやproduction昇格へ進む
価値は現時点ではなく、このformulationは停止する。

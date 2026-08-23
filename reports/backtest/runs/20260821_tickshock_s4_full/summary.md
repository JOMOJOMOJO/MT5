# Tick Shock Scalper Stage 4 preliminary result

> **INVALIDATED 2026-08-21:** このrunは、baselineとsignalの統計量不一致、全通貨tickの非merge処理、signal後shadowの同一batch取りこぼし、continuation/reversalの非対称cost gate、MFE/MAE anchor誤りが確認されたため、edge判定には使用しない。以下は無効化前の監査対象記録であり、現在の正式判定は `VALIDATION_INVALID / EDGE_UNDETERMINED`。

## Verdict

~~`NO_EDGE_OBSERVED`~~ → `VALIDATION_INVALID / EDGE_UNDETERMINED`

2025-03-01から2025-03-31までの初期1か月EVENT_STUDY。MT5設定の終了境界を2025-04-01として3月31日を含めた。閾値最適化なし、6通貨、Model 4、deposit 10,000 USD、leverage 1:100、risk 0.25%、RR 1.2、最大保有120秒。

サンプルは期待値を証明するには不足しているが、現定義では再加速8件がすべてコスト制約で実行不可で、順張り・逆張りshadowも負だった。したがって `PROMISING_BUT_INSUFFICIENT_SAMPLE` ではなく `NO_EDGE_OBSERVED` とする。

## Stage results

| Stage | Period | Events | Pullbacks | Reacceleration | Actual trades | Runtime |
|---|---|---:|---:|---:|---:|---:|
| 2 EVENT_STUDY | 2025-03-03..05（3営業日） | 25 | 19 | 5 | 0 | 85.890 s |
| 2 BACKTEST_TRADE | 2025-03-03..05（3営業日） | 25 | 19 | 5 | 0 | 84.336 s |
| 3 EVENT_STUDY | 2025-03-03..07（5営業日） | 33 | 23 | 7 | 0 | 134.355 s |
| 4 EVENT_STUDY | 2025-03-01..31 | 47 | 34 | 8 | 0 | 366.112 s |

Stage 4はraw shock candidates 65,616、EA処理ティック10,587,794、Long/Short 25/22、event ID 47/47 unique、全47イベントで120秒checkpointを保存した。Stage 2のEVENT_STUDYとBACKTEST_TRADEは同一funnelで、EVENT_STUDYは注文せず、BACKTEST_TRADEも実行可能候補がないため注文0だった。

## Symbol breakdown

| Symbol | Raw candidates | Events | Pullbacks | Reacceleration | Continuation N / ER | Reversal N / ER |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD | 4,495 | 6 | 4 | 0 | 0 / n/a | 5 / -0.087933 |
| GBPUSD | 7,171 | 4 | 3 | 0 | 0 / n/a | 3 / -0.252144 |
| USDJPY | 28,513 | 17 | 11 | 4 | 4 / -1.000000 | 6 / -0.178152 |
| AUDUSD | 8,788 | 1 | 1 | 0 | 0 / n/a | 1 / +0.051020 |
| USDCAD | 13,877 | 19 | 15 | 4 | 4 / -0.449405 | 14 / -0.454497 |
| USDCHF | 2,772 | 0 | 0 | 0 | 0 / n/a | 0 / n/a |

6通貨すべてでティック取得は成功したが、USDCHFは有効shock event 0件だった。利益が特定通貨へ依存するかは、実取引0件のため評価不能。

## Session and HTF diagnostics

| Session | Events | Continuation N / ER | Reversal N / ER |
|---|---:|---:|---:|
| TOKYO | 3 | 1 / -1.000000 | 1 / -0.777778 |
| LONDON | 4 | 1 / -1.000000 | 1 / +1.193548 |
| NEW_YORK | 17 | 3 / -0.265873 | 14 / -0.310348 |
| OVERLAP | 16 | 1 / -1.000000 | 10 / -0.164785 |
| OTHER | 7 | 2 / -1.000000 | 3 / -1.000000 |

HTFは `BOTH_ALIGNED` が9イベントで、continuation 1件 +1.202381R、reversal 5件 +0.677510R。一方、`CONFLICT` は18イベントでcontinuation 5件 -1.000000R、`NEUTRAL` は14イベントでcontinuation 2件 -1.000000Rだった。正のaligned群は少数すぎるため、初期baselineのエントリーフィルターには昇格しない。

## Execution stress

各セルは8件のcontinuation shadowの平均R。

| Delay | Spread 1.0 | Spread 1.25 | Spread 1.5 |
|---:|---:|---:|---:|
| 0 ms | -0.724702 | -0.725138 | -0.724490 |
| 100 ms | -0.449953 | -0.449550 | -0.450410 |
| 250 ms | -0.449928 | -0.449480 | -0.450275 |
| 500 ms | -0.725806 | -0.725314 | -0.724919 |

100/250msで数値が改善したのは遅延が偶然有利に働いた観測であり、全scenarioが負なのでexecution robustnessとはみなさない。baseline continuation shadowは8件でExpectancyR -0.724702、reversal shadowは29件で -0.295757。

## Skip reasons, storage, memory

イベント成立後は `continuation_invalidated` 29、`cost_too_large_vs_risk` 8、`no_reacceleration` 6、`pullback_too_shallow` 4。急変前の不成立はevent CSVへ出さずsummary件数だけに集約した。

- 1秒ring: 1通貨902 samples上限
- tick ring: 1通貨4,096 samples上限。5,000ms超またはcapacity超過で古いtickを破棄
- active event: 全体64 slots上限、追跡は最大120秒
- MQL program memory: 平均/最大 2/2 MB
- Strategy Tester終了時: 501 MB（history 40 MB、tick data 256 MBを含む。EAリングだけの値ではない）
- event CSV: 47 data rows、35,677 bytes
- trade CSV: 0 data rows、392 bytes（headerのみ）
- summary CSV: 98 data rows、30,612 bytes
- tick CSV / 1秒CSV: 出力なし

同程度のイベント密度なら、event CSVは約35.7 KB/月、約0.43 MB/年。summaryを月ごとのrunごとに保存する場合の全CSVは約66.3 KB/月、約0.80 MB/年。trade行は今回0件のため、この見積りには将来のtrade recordを含めない。MT5の履歴・tick cacheは別容量である。

## Data quality and continuation decision

MT5 agentは6通貨を処理し、2025-03-31 23:57:59まで完走した。GBPUSDは30,187 minute bars中179分（約0.59%）でreal ticksが破棄され、every-tick generationへfallbackした。USDCAD/USDCHFのreal tick履歴開始は2025-03-03で、3月1・2日は週末だった。

有効な実行可能continuationは0件/月なので、30 actual tradesへ必要な月数は有限推定できない。再加速shadowだけなら8件/月から約3.75か月だが、これは有効取引サンプルではない。結論は `insufficient statistical evidence` を伴う `NO_EDGE_OBSERVED` で、現定義のまま長期OOSへ進む価値は認めない。複数年テストと最適化は実行せず、次の指示を待つ。

Supporting artifacts: [events CSV](./ExpectedValue_MultiCurrency_TickShockScalper_stage4_202503_full_event_final_events.csv), [trade CSV](./ExpectedValue_MultiCurrency_TickShockScalper_stage4_202503_full_event_final_trades.csv), [summary CSV](./ExpectedValue_MultiCurrency_TickShockScalper_stage4_202503_full_event_final_summary.csv).

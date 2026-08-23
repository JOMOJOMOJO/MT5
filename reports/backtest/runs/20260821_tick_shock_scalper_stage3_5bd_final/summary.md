# Tick Shock Scalper Stage 3 one-week result

期間は2025-03-03から2025-03-07の5営業日。MT5設定の排他的終了境界は2025-03-08。6通貨、EVENT_STUDY、real-tick Model 4、最適化なし。

## Funnel and resources

- raw shock candidates: 28,193
- valid shock events / bursts: 33 / 33
- valid pullbacks: 23
- reacceleration signals / continuation shadows: 7 / 7
- continuation shadow ExpectancyR: -0.685374
- reversal shadow trades / ExpectancyR: 22 / -0.193414
- actual continuation trades: 0
- processed ticks: 3,337,011
- MQL program memory average / max: 2 / 2 MB
- Strategy Tester終了時memory: 352 MB（history/tick dataを含む）
- event CSV: 33 rows / 25,268 bytes
- trade CSV: 0 rows / 392 bytes
- summary CSV: 29,782 bytes
- Strategy Tester runtime: 134.355 seconds（EA集計134.250秒）

## Symbol counts

| Symbol | Raw | Events | Pullbacks | Reacceleration | Reversal shadows |
|---|---:|---:|---:|---:|---:|
| EURUSD | 2,575 | 4 | 3 | 0 | 4 |
| GBPUSD | 3,638 | 3 | 2 | 0 | 3 |
| USDJPY | 9,900 | 10 | 6 | 3 | 4 |
| AUDUSD | 4,780 | 1 | 1 | 0 | 1 |
| USDCAD | 5,426 | 15 | 11 | 4 | 10 |
| USDCHF | 1,874 | 0 | 0 | 0 | 0 |

Session eventsはTOKYO 2、LONDON 2、NEW_YORK 14、OVERLAP 9、OTHER 6。イベント成立後の主な失効理由は `continuation_invalidated` 22、`cost_too_large_vs_risk` 7、`pullback_too_shallow` 2、`no_reacceleration` 2。急変前は `shock_percentile_failed` 799,950、`insufficient_baseline` 452,178、`invalid_robust_scale` 408,828が上位で、summary件数だけに保存した。

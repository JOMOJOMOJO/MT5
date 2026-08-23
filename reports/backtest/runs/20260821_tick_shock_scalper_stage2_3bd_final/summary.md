# Tick Shock Scalper Stage 2 smoke result

期間は2025-03-03から2025-03-05の3営業日。MT5設定の排他的終了境界は2025-03-06。6通貨、real-tick Model 4、最適化なし。

| Mode | Raw candidates | Events | Pullbacks | Reacceleration | Trades | MQL avg/max | Event CSV | Trade CSV | Tester runtime |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| EVENT_STUDY | 17,151 | 25 | 19 | 5 | 0 | 2/2 MB | 25 rows / 19,290 B | 0 rows / 392 B | 85.890 s |
| BACKTEST_TRADE | 17,151 | 25 | 19 | 5 | 0 | 2/2 MB | 25 rows / 19,290 B | 0 rows / 392 B | 84.336 s |

全6通貨でティック取得に成功し、処理件数はEURUSD 252,941、GBPUSD 280,404、USDJPY 560,213、AUDUSD 323,366、USDCAD 383,920、USDCHF 227,958。event funnelとevent IDはmode間で一致し、EVENT_STUDYは注文なし。BACKTEST_TRADEは5再加速がすべてexecution cost gateで失効したため注文なし。古い境界tickの再取得は検出・破棄され、eventの二重記録はなかった。

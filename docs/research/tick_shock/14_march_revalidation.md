# Tick-shock研究EA Step 14：2025年3月再検証

## 実行条件

- production source commit: `d25d2e655b585ca9c1b84d5041690531e07f4dc3`
- driver: `EURUSD,M1`
- symbols: `EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF`
- period: `2025-03-01` through `2025-04-01`
- model: MT5 real ticks / model 4
- broker/server: `VantageTradingLtd-Live`
- terminal: MetaTrader 5 Build 6140
- RR: 1.2、最大保有120秒
- optimization、threshold変更、stop grid変更、strategy選択、長期OOSは未実施
- 研究EAは`OrderCheck`／`OrderSend`を持たず、tester report上も注文・約定0件
- raw tick CSVおよび1秒時系列CSVは出力していない

## 事前GREEN gate

正式コマンドをStep 14開始前に再実行した。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_all_tests.ps1 -TimeoutSeconds 45 -Phase post-fix
```

- PASS 81
- FAIL 0
- XFAIL 0
- XPASS 0
- SKIP 9
- BLOCKED 0
- research EA＋11 harness: すべて0 errors / 0 warnings

SKIP 9はactual terminal／brokerで未観測の項目であり、PASSへ読み替えていない。

## Run

- IDEAL: `reports/backtest/runs/20260823_tickshock_step14_ideal_202503/`
- REALIZABLE: `reports/backtest/runs/20260823_tickshock_step14_realizable_202503/`
- comparison: `reports/backtest/runs/20260823_tickshock_step14_comparison_202503/`

両runはfresh runとして実行し、既存RunIdへのappend／resumeは行っていない。各runの`.runmeta`はperiod、model、server、build、source commit、EX5 hash、schema、config fingerprintが一致した。

## Step 7 regression

REALIZABLE同士の比較は16項目すべてPASSだった。

| 指標 | Step 7 | Step 14 |
|---|---:|---:|
| raw candidates | 62,577 | 62,577 |
| event rows | 19 | 19 |
| valid bursts | 19 | 19 |
| valid pullbacks | 14 | 14 |
| reacceleration | 5 | 5 |
| reversal signals | 11 | 11 |
| symbol clusters | 17 | 17 |
| market clusters | 15 | 15 |
| Long / Short events | 10 / 9 | 10 / 9 |

event key、scenario membership、scenario status、policy mask、gross/net R、signal／processing／eligible／entry／exit clocksの差分は0。戦略パラメータおよび研究結果の構造的挙動は保存されている。

## IDEALとREALIZABLE

| 指標 | IDEAL | REALIZABLE |
|---|---:|---:|
| valid scenario cells | 7,128 | 7,128 |
| invalid broker cells | 324 | 324 |
| TP | 1,301 | 1,227 |
| SL gap | 2,840 | 2,820 |
| TIME | 2,987 | 3,081 |
| diagnostic grid mean R | -0.302408 | -0.292362 |
| runtime (EA summary) | 373.547秒 | 372.797秒 |
| tester wall run | 381.817秒 | 378.834秒 |

REALIZABLEのunique decision actual delay平均は675.660ms、p50は570ms、p95は1,159.1ms。IDEALはevent-time診断専用で、正式判定には使用していない。

## REALIZABLE scenario診断

| Strategy | valid cells | TP | SL | TIME | diagnostic ExpectancyR |
|---|---:|---:|---:|---:|---:|
| detection-time continuation | 2,508 | 432 | 987 | 1,089 | -0.319703 |
| post-burst continuation | 2,508 | 441 | 1,047 | 1,020 | -0.339913 |
| pullback continuation | 660 | 180 | 279 | 201 | -0.218739 |
| failed-shock reversal | 1,452 | 174 | 507 | 771 | -0.196465 |

Longは-0.053791R、Shortは-0.530932Rだった。通貨別ではUSDJPYのみ+0.105327Rだが、これはcorrelated grid cellの診断値であり、通貨選択や採用判断には使わない。session／HTF別結果はREALIZABLE `summary.md`に全件記録した。

## Commission

Step 13では12 entry/exit dealsの`DEAL_COMMISSION`、`DEAL_FEE`、`DEAL_SWAP`がtester history上すべて0として観測された。しかし、これはlive Vantage口座のcommissionが0である証拠ではない。

- configured value: 0.0
- source: `STEP13_TESTER_DEAL_FIELDS_OBSERVED_ZERO_LIVE_UNVALIDATED`
- numeric gross Rとnet Rは今回一致
- formal classification: `COST_MODEL_INCOMPLETE`
- formal net result: `FORMAL_NET_EXPECTANCY_UNAVAILABLE`

## Policy mask=3

REALIZABLEで両方の元policy条件を満たしたのは21 cells、1 event、1 symbol cluster、1 market clusterだった。

- strategy: post-burst continuationのみ
- direction/symbol: SHORT / USDCAD
- TP / SL / TIME: 0 / 21 / 0
- diagnostic gross/net mean: -1.180927R
- average / median hold: 0.556秒 / 0.491秒

これはdiagnostic sliceであり、採用strategy、positive cell探索、parameter selectionには使用していない。

## Feasibility層の分離

| 層 | 観測 | 判定 |
|---|---|---|
| broker-grid shadow feasible | 7,128 barrier cellsが生成 | run invalidのため診断のみ |
| original cost/range policy feasible | mask=3が21 cells / 1 market cluster | run invalidのため診断のみ |
| order lifecycle observed | Step 13でOrderCheck/OrderSend/full fill/server SL/TP/time closeをtester観測 | PARTIALLY_OBSERVED |
| deployable feasibility | global frontier integrity失敗、live commission未確定 | NOT_ESTABLISHED |
| edge evidence | strategy未選択のcorrelated grid | UNDETERMINED |
| statistical sufficiency | formal n候補15 market clusters | INSUFFICIENTかつrun invalid |

## 因果性・整合性

REALIZABLEで以下はすべて0 violationsだった。

- entry >= signal + requested delay
- entry >= processing + submit latency
- entry >= eligible、entry > signal
- stale Detection boundary fill
- reversal signal時刻上書き
- realized RR < 1.2
- global chronological order violation
- duplicate event
- market cluster不整合
- CSV／summary再集計不一致
- net R二重commission控除
- StopsLevel／FreezeLevel不整合
- RunId／fingerprint不整合
- research EA trade rows

causal clock violationsは0であり、execution clock自体は`EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY`と評価できる。

## Fail-closed data-quality finding

両runはStep 12のintegrity監視により次を記録した。

- validation: `VALIDATION_INVALID`
- fatal reason: `INCOMPLETE_GLOBAL_FRONTIER`
- stale symbols: 3
- max frontier lag: 3,707ms
- event pool exhaustion: 0
- pending capacity hits: 0
- dropped ticks: 0
- cursor stalls: 0
- incomplete_frontier flag: false

したがって、causal clockが合格しStep 7 regressionが完全一致しても、このrunを正式なfeasibility／edge証拠には使用できない。fail-closed status 1件とstale-symbol instance 3件を合わせ、formal validation violation instanceは4件である。

## Tick quality・メモリ・データ量

- GBPUSD: generated fallback 179 / 30,187 tester minutes（0.5930%）
- 他5通貨: discard warning未観測。全quoteがbroker real tickだった証明ではない
- EA集計 memory: average 10.000MB / max 10MB
- tester process memory: IDEAL 484MB / REALIZABLE 513MB（history/tick生成領域を含む）
- 1秒ring logical cap: 904 samples / symbol
- tick ring cap: 8,192 ticks / symbol
- tick破棄: 5,000msより古い、またはcapacity到達時
- global pending cap / max observed: 65,536 / 319
- REALIZABLE events.csv: 19 rows / 5,149,476 bytes
- REALIZABLE summary.csv: 1,185 rows / 207,602 bytes
- REALIZABLE trades.csv: 0 rows / 15 bytes

現行schemaとMarch event密度が線形に続く仮定では、REALIZABLEのstructured CSVは概ね約5.36MB/月、約64.3MB/年。IDEALも常時保存すれば概ね倍になる。raw tickや1秒CSVは含まれない。

## 最終判定

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY`
- `VALIDATION_INVALID`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- `LONG_OOS_NOT_AUTHORIZED`

長期OOSへは進まない。次のpromotion gateは、strategy thresholdを変えず、global watermarkのstale symbol／frontier fail-closed条件が「実データ欠損」なのか「現在の市場意味・監視定義による失効」なのかを別Stepで診断し、正式run integrityを`VALIDATION_OK`にできること、およびlive commissionの観測または明示的な保守cost modelを確定することである。

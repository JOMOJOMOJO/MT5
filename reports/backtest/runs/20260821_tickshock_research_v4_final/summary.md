# Tick-shock research v4 final report

## 判定

- 旧`NO_EDGE_OBSERVED`は撤回する。
- 旧runの判定: `VALIDATION_INVALID`
- 修正版v4のedge判定: `EDGE_UNDETERMINED`
- 長期検証: 進めない。現在定義では1か月に実行可能なshadow outcomeが0件で、期間延長だけではExpectancyRを推定できない。

修正版は検証実装の欠陥を解消したが、2025年3月のサンプルでは全252 execution scenarioが`INVALID_STOP_VS_BURST`となった。これは負の期待値を観測した結果ではなく、`spread/risk <= 0.20`と`risk/burst <= 0.45`を同時に満たすbarrierが得られなかったという実行可能性の結果である。

## 修正内容

- baselineとsignalを同じ固定250ms gridの1,000ms log-mid returnへ統一。
- 500ms quote-age上限と1 tick noise floorを追加し、MAD=0を一律無効にしない。
- 全通貨tickを`time_msc`, symbol, sequenceでマージし、通貨別frontierのwatermarkより古いtickだけをrelease。
- 同一CopyTicks batchのtickもstate/MFEへ含める。
- shadow fillは`max(signal + delay, processing time)`以降の最初のBid/Askに限定し、過去価格へ遡らない。
- 全イベントを独立追跡し、symbol間のscore rankingを廃止。
- detection/burst-end双方をanchorに、1/2/5/10/30/60/120秒のBid/Ask/MFE/MAEを保存。
- immediate continuation、pullback continuation、failed-shock reversalを同じspread/slippage/commission/stop feasibilityで比較。
- 研究EAから注文処理を分離し、Strategy Tester専用order harnessを追加。

## Stage 1

- Research reachability: 18/18 PASS。
- Order reachability: 8/8 PASS。
- 実テスター注文: Long/Shortとも`OrderCheck -> OrderSend -> entry fill -> position field recovery -> close fill`を完了。
- 実partial fill: 発生せず。複数dealの加重平均集計は決定論テストのみ。
- プロセス再起動: 未注入。保有中positionのmagic/time/volume/open price復元は実positionで確認。

## Staged real-tick results

MT5 Strategy Testerは`100% リアルティック`、初期証拠金10,000 USD、レバレッジ1:100、最適化なし。研究EAのtester注文・約定は0件。

| Stage | 期間 | 全通貨tick | raw candidates | events | bursts | pullbacks | reacceleration | scenario valid | runtime | avg/max memory | event CSV |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 2025-03-03..06 | 2,028,802 | 1,807 | 4 | 4 | 3 | 1 | 0 | 42.750s | 7/7MB | 4行 / 24,478B |
| 3 | 2025-03-03..10 | 3,337,011 | 2,993 | 6 | 6 | 3 | 1 | 0 | 70.984s | 7/7MB | 6行 / 31,182B |
| 4 | 2025-03-01..04-01 | 10,587,794 | 5,962 | 7 | 7 | 4 | 2 | 0 | 156.250s | 7/7MB | 7行 / 34,606B |

全Stageで`order_violations=0`、global pending capacity hit 0。Stage 4の最大pendingは319/65,536件。

## Stage 4 event distribution

- direction: Long 3、Short 4。
- symbol: EURUSD 2、GBPUSD 2、USDJPY 1、USDCAD 2、AUDUSD 0、USDCHF 0。
- session: NEW_YORK 4、LONDON 1、OVERLAP 1、OTHER 1、TOKYO 0。
- HTF alignment: BOTH_ALIGNED 1、H1_ONLY 2、CONFLICT 2、NEUTRAL 2。
- final state: failed-shock reversal 5、pullback reacceleration 2。
- detection/burst checkpoint: 7イベントすべてで全14 horizonが完了。

## Execution comparison

- Immediate continuation: 126 scenarioが`INVALID_STOP_VS_BURST`。
- Pullback continuation: 36 scenarioが同理由、90 scenarioは`NO_SIGNAL`。
- Failed-shock reversal: 90 scenarioが同理由、36 scenarioは`NO_SIGNAL`。
- delay 0/100/250ms、spread 1.0/1.25、stop 5/8/12x spreadの全条件で成立損益0件。
- 0/100/250msの実entry delayはprocessing floorが支配し、entryできた6イベントではすべて465～589ms、平均521.3ms。1イベントはentry前にfeasibility不成立。
- commissionは`UNCONFIRMED_ZERO_ASSUMPTION`。成立損益が0件のためExpectancyR、PF、win rate、hold timeは計算不能。

## Storage and buffers

- 1秒sample: 902件/通貨。
- tick ring: 8,192件/通貨。5,000msより古いtick、またはcapacity超過時の最古tickを破棄。
- grid: 64件/通貨。
- active events: 128件。
- global pending: 65,536件上限。Stage 4最大319件、capacity hit 0。
- tick/250ms/1秒CSV: 出力なし。
- Stage 4 trade CSV: 0行 / 15B（research-only header）。
- Stage 4 event CSV: 7 unique event IDs、7行、320列、34,606B。1イベント1行を確認。
- Stage 4 summary CSV: 21,529B、symbol specs: 1,413B。4 CSV合計57,563B。
- 観測レート単純換算: 約690,756B/年、43か月で約2,475,209B。HTML、画像、MT5履歴cacheは除く。

## 結論

Long/Shortの実市場状態到達と6通貨tick監視は確認できたが、AUDUSD/USDCHFの有効event、30件の有効順張り取引、cost後ExpectancyRは得られていない。現行定義の実行可能sample rateは0件/月なので、必要月数は有限に推定できない。閾値を緩和して件数を作ることはせず、このタスクでは長期OOSへ進まない。

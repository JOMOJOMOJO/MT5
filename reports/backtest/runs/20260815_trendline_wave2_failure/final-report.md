# TRENDLINE_WAVE2_FAILURE 最終報告

## 1. 調査した既存構造

基礎EAは `ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.mq5`。既存bucketはH1親構造転換、M15 Wave1/Wave2、M5子構造反転を、6通貨のM5確定足ごとに走査する。左右深さ確定pivot、equity risk sizing、`CTrade`、Magic限定管理、状態／取引／funnel／reject CSVを持つ。

## 2. 変更ファイル

- EA統合点: `mql/Experts/ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.mq5`
- 新bucket本体: `mql/Include/TrendlineWave2Failure.mqh`
- run生成／実行／集計: `scripts/generate-trendline-wave2-failure-runs.ps1`、`scripts/run-trendline-wave2-failure-batch.ps1`、`scripts/analyze-trendline-wave2-failure.py`
- 証拠: このディレクトリ以下のpreset、tester ini、MT5 HTML、CSV、PNG、集計。

既存bucketは削除・置換していない。既定値は `BUCKET_LEGACY_ONLY`。新bucketは別状態、別Magic、別CSVを使う。Combined時だけ既存注文にも統合portfolio/currency/margin/loss gateを適用する。

## 3. 新戦略の状態遷移

`IDLE → H4_IMPULSE_DETECTED → H1_STRUCTURE_RECONSTRUCTED → H1_TREND_MATURE → H1_TRENDLINE_BROKEN → H1_REVERSAL_LEG → M15_PULLBACK_ACTIVE → M15_CONTINUATION_FAILED → M15_STRUCTURE_BROKEN → ENTRY_READY → POSITION_OPEN`

失効先は `INVALIDATED` または `EXPIRED`。同じ評価時点で複数条件が既知なら複数段進める。H4認識前に成立済みのH1状態は再構築するが、過去注文は生成しない。

## 4. SOURCE_RULE / OPERATIONAL_DEFINITION / RESEARCH_PARAMETER

- `SOURCE_RULE`: H4構造破壊急変、H1複数波成熟、H1トレンドライン突破、第2波候補、M15旧方向継続失敗、保護スイング突破。
- `OPERATIONAL_DEFINITION`: SMA20傾き区間の確定スイング、確定スイング系列による成熟、時刻補間trendline、M15保護スイングと状態遷移。
- `RESEARCH_PARAMETER`: ATR倍率、percentile、2本傾き確認、pattern許容、72/32本失効、buffer、固定2R、0.5% risk等。元資料の推奨値とは扱わない。

## 5. スイング確定と未来参照防止

全データは `CopyRates(..., start_pos=1, ...)` 相当の既存 `CopyClosedRates` から取得する。SMA normalized slopeが指定本数連続して反転した時点で旧区間の極値を確定する。各Swingは `pivotTime` と `confirmationTime` を保存し、評価時刻以下のconfirmationだけを利用する。H4/H1/M15ごとにshift 1の時刻更新を監視し、同じ確定足を重複評価しない。初期化時に最新確定足をclockへ入れ、過去シグナルを注文しない。

## 6. H4急変

N=1/2/3について、候補開始直前ATRを分母に `NormalizedMove`、TR合計による `DirectionalEfficiency`、window内 `CloseLocation` を計算する。候補以前250本の同一N分布からpercentileを求める。事前H4 trend、protected swing、buffer付き終値構造破壊を要求し、複数N成立時は `NormalizedMove × efficiency × percentile/100` 最大だけを採用する。

## 7. H1・M15構造

- H1成熟: 反対方向の高値／安値更新を各2回以上、かつ開始ATR比2.5以上または12本以上。
- H1 trendline: 下降時は直近2 SwingHigh、上昇時は直近2 SwingLow。最低3本、0.1ATRの高さ、0.05ATR bufferで確定終値cross。
- M15 pullback: H1 break後に旧方向の高値・安値更新が各1回以上。
- M15 failure: equal double、higher low/lower high、false-break recovery、tripleを診断分類し、pattern heightとageを確認。売買中心条件はM15 protected swingの確定終値break。

## 8. Entry / SL / 2R

M15保護スイングをpoint/ATR buffer付きで終値cross後、次tick成行。M15 SMA方向、最大0.5ATR extension、最大1.5ATR break candleを確認する。SLは `FULL_PATTERN_EXTREME / LATEST_M15_SWING_EXTREME / H1_WAVE2_EXTREME`。spreadとATRの大きいbufferを使い、StopsLevel/FreezeLevel補正は広げる方向だけ。初期正式runはFULL_PATTERN_EXTREME、固定2R。

## 9. Lot / total risk / currency-direction risk

`FIXED_LOT / PERCENT_RISK` を実装。percent riskはequity 0.5%、`OrderCalcProfit()` の1lot損失からvolume stepへ切り下げる。minimum lotがrisk budgetを超える場合は拒否。総open risk 2%、total positions 4、symbol 1、same direction 3、setup 1。`SYMBOL_CURRENCY_BASE/PROFIT` による同一通貨同一方向risk 1%。通貨を特定できない場合はsymbol capだけを適用しwarningを残す。

## 10. 停止機能

日初equity -2%、週初 -4%、EA high-water -10%。日週はserver timeで更新し、hard stopは自動解除しない。terminal global variablesへ基準equity、keys、stop flagsを保存する。defaultでは既存positionを強制決済しない。emergency disableを持つ。

## 11. Compile

[MetaEditor log](../../../compile/trendline_wave2_failure.log): `Result: 0 errors, 0 warnings`。最終OOS lockと現在のsource/include SHA-256は一致した。

## 12. MT5テスト条件

- M15 chart、Model=4 `Every tick based on real ticks`
- internal H4/H1/M15、6 FX symbols
- USD 10,000、1:100
- 2024-01-01〜2024-12-31、2025-01-01〜2025-12-31、2026-01-01〜2026-08-14
- 最終処理時刻: 2026-08-13 23:57:55
- optimizationなし、全run同一strategy parameters。run ID、Magic、log folderだけ隔離。
- 2026を見る前のlock: [oos_lock.json](oos_lock.json)

## 13. 年別・通貨別・方向別結果

新bucketは全期間0 trades。したがって通貨別、Long/Short別、pattern別、cost R、MFE/MAE、win rate、PF、expectancyは未推定。H4 candidateの通貨・方向内訳は [state breakdown](new_bucket_state_by_symbol_direction.csv)。H1 TL breakは2024 USDJPY Short、2025 EURUSD Short/AUDJPY Short、2026 GBPUSD Short。M15 pullbackへ到達したのは2025 EURUSD ShortとAUDJPY Shortだけ。

既存bucketの詳細値は [comparison.csv](comparison.csv)。主要値:

| Year | Mode | Trades | Win% | Net | PF | Net exp R | Closed DD | Equity DD | Max losses | Avg hold min | Long/Short |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2024 | Baseline | 147 | 46.26 | -17.61 | 0.986 | +0.0033 | 330.79 | 352.44 (3.49%) | 9 | 106.4 | 73/74 |
| 2025 | Baseline | 173 | 43.35 | -545.96 | 0.686 | -0.1317 | 548.19 | 549.69 (5.49%) | 7 | 105.8 | 73/100 |
| 2026 | Baseline | 36 | 47.22 | +32.99 | 1.115 | +0.0320 | 92.66 | 112.22 (1.11%) | 4 | 119.7 | 15/21 |

## 14. Baseline / New only / Combined

| Year | Baseline | New only | Combined |
|---:|---|---|---|
| 2024 | 147 trades / -17.61 | 0 / 0.00 | 147 / -17.49 |
| 2025 | 173 / -545.96 | 0 / 0.00 | 172 / -523.00 |
| 2026 | 36 / +32.99 | 0 / 0.00 | 36 / +32.99 |

2025 Combinedは `combined_same_direction_position_cap` が既存候補1件を拒否した。2024の0.12差は同一147取引中1件の約定価格1point差。

## 15. Gate別通過数

| Year | H4 impulse | H1 mature | H1 TL break | M15 pullback | M15 failure | M15 break | Execution pass | Orders |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2024 | 80 | 4 | 1 | 0 | 0 | 0 | 0 | 0 |
| 2025 | 48 | 3 | 2 | 2 | 0 | 0 | 0 | 0 |
| 2026 | 40 | 1 | 1 | 0 | 0 | 0 | 0 | 0 |

## 16. reject_reason

新bucket: H4 opposite structure updateが2024=68、2025=41、2026=32。2026にH1 wave1 origin breakが1。Executionへ到達しないためcost/risk/margin rejectionは0。全bucket: [rejection_reasons.csv](rejection_reasons.csv)。

## 17. 代表時系列

実取引がないため代表tradeは存在しない。代わりに2025の2 near-missを [representative_setup_timeline.csv](representative_setup_timeline.csv) に保存した。

- EURUSD Short: 2025-01-27 H4 impulse → 02-07 H1 mature/TL break → 02-12 M15 pullback → H1 expiry。
- AUDJPY Short: 2025-02-12 H4 impulse → 03-03 mature → 03-10 TL break → 03-11 M15 pullback → M15 pattern expiry。

## 18. 既知制約

- 新bucket注文0のため、新bucketのvolume rounding、post-fill risk tolerance、SL/TP modify、portfolio/currency/margin reject、deal exit CSVは実注文で未到達。
- commission inputはdefault `-1=unavailable`。spreadは必須計上、slippageは設定値を計上するが、未取得commissionの状態は専用列ではなくinputで識別する。
- trendline touch countは初期版でanchor 2点を記録するだけで、追加touchの厳密集計ではない。
- H4反対構造更新は「impulse後にbuffer付き終値でwindow extremeを更新」と定義した。代替は確定H4 swing更新であり、setup生存期間が長くなる可能性がある。
- 再起動position recovery後のMFE/MAEは再起動以前を復元しない。

## 19. 実装問題と期待値問題の分離

- 実装確認: compile成功、closed-bar clock作動、状態CSV生成、New/Combined funnel一致、全9runでMT5 deal数と独自trade数一致、2026 lock一致。
- 未検証実装経路: 新bucketの実注文後処理とrisk rejection。
- 戦略側: 現行条件積では3期間合計でもM15 failure 0件。期待値が負と結論する標本すらなく、主問題はtrade funnelの希少性。

## 20. 次の仮説

1. 2024/2025だけで、H4 opposite structure updateを現在の終値定義と確定H4 swing定義で1要因比較する。2026を再利用してOOSとは呼ばない。
2. M15 protected swing不足、pattern age、height、failure classの非取引診断カウンタを追加する。
3. 注文標本が得られた後に限り、FULL_PATTERN_EXTREMEと固定2Rを維持してcost/lot/risk実経路を検証する。symbol、direction、session、TPを同時に変更しない。

## 結論

実装と計測基盤は完成し、初期固定runも完了した。ただし新bucketは0 tradesでpromotion不可。条件を利益目的で緩和せず、research bucketとして次のfunnel診断へ進む。

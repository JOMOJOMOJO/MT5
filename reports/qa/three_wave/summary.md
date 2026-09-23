# 3Wave-in-3Wave LONG EA 検証結果

## 結論

新インジケーターの判定を共通モジュールへ切り出し、既存EAの注文・資金管理を引き継いだ **USDJPY_M1_M5_3WaveIn3Wave_Long** を作成した。Fib50 Buy Limitは新EAに含めず、確定したREADYの次の利用可能ティックで成行BUYする。

ユーザー回答に従い、原版の表示をそのまま再現することより、無効化ルールを厳密に守ることを優先した。原版と旧EAは変更せず保存。比較対象は修正版 **MultiTF_3WaveIn3Wave_Visualizer_Shared（内部バージョン1.06）**。

**最適化・パラメータ調整は行っていない。** 検証期間の成績はマイナス。ロジック一致を確認したことと、収益性を確認したことは別である。

## 1. 作成・変更ファイル

| ファイル | 内容 |
|---|---|
| [USDJPY_M1_M5_3WaveIn3Wave_Long.mq5](../../../mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5) / 同名EX5 | 新しい成行版EA。旧EAは変更しない |
| [ThreeWaveStructure.mqh](../../../mql/Include/ThreeWaveStructure.mqh) | 唯一の構造・ピボットエンジン |
| [ThreeWaveInputs.mqh](../../../mql/Include/ThreeWaveInputs.mqh) | インジケーターとEAの共通設定 |
| [ThreeWaveDrawing.mqh](../../../mql/Include/ThreeWaveDrawing.mqh) | 共通の構造描画 |
| [ThreeWaveExecutionBase.mqh](../../../mql/Include/ThreeWaveExecutionBase.mqh) | 旧EAの所有権・件数・Filling・取消・決済関数を継承 |
| [MultiTF_3WaveIn3Wave_Visualizer_Shared.mq5](../../../mql/Indicators/MultiTF_3WaveIn3Wave_Visualizer_Shared.mq5) / 同名EX5 | 共通エンジンを使う修正版インジケーター |
| [構造テスト](../../../mql/Scripts/tests/ThreeWaveStructure_Validation.mq5)、[執行テスト](../../../mql/Scripts/tests/ThreeWaveExecution_Validation.mq5) | ネイティブMQL5テスト。執行テストは発注APIをモックへ置換 |
| [原版比較](../../../mql/Scripts/tests/ThreeWaveOracleComparison.mq5)、[原版エンジン](../../../mql/Scripts/tests/ThreeWaveOriginalOracle.mqh) | 原版の関数名だけ隔離した独立比較用コード。製品には含めない |
| [実行スクリプト](../../../tools/swing_structure/run-three-wave.ps1)、[監査・集計](../../../tools/swing_structure/audit_three_wave.py)、[画面取得](../../../tools/swing_structure/capture-tester-window.ps1) | 独立テスター・再現・証拠取得 |

差分：[構造エンジン](shared_engine_changes.diff)、[旧EA対新EA](ea_changes.diff)。原本のハッシュは [baseline_hashes.json](baseline_hashes.json)。最終ファイルの一覧・ハッシュは [manifest.json](manifest.json)。

修正版インジケーターのMQ5/EX5は、この端末の `MQL5/Indicators/` に配置済み。必要な共通ヘッダー3本も `MQL5/Include/` に配置した。EAのMQ5/EX5は指定リポジトリの `mql/Experts/` にあり、MT5ナビゲータから利用できる。

## 2. 状態機械と発注仕様

### 構造状態（共通エンジン）

1. `WAIT_M5_DOWNTREND`：最新高値2点・安値2点が切り下がる下降構造を探す。
2. `M5_WAVE1_ACTIVE`：確定M5終値が戻り高値を上抜く。起点安値を固定。
3. `M5_WAVE2_ACTIVE / WAIT_M1_DOWNTREND`：CHoCH以後のM5高値ピボットが確定し、M1構造を監視。
4. `M1_WAVE1_ACTIVE`：確定M1終値のCHoCH。反転安値を固定。
5. `M1_WAVE2_ACTIVE`：M1 Wave1高値確定後、新しい確定HLと押し内部の戻り高値を追う。
6. `LONG_READY`：戻り高値の確定終値ブレイクを優先。該当戻り高値がなければWave1高値ブレイク。

M5起点割れでM5仮説を破棄。M1反転安値割れではM5を維持し、失敗時刻以降の新しいM1ピボットから下降構造を再探索。HL割れでは古いHLと戻り高値を無効にし、新しい確定HLを待つ。同じ足に無効化と上抜きがあれば無効化を優先する。確定済みの過去READYは、その後の値動きによって削除しない。

ピボットは `bar_time` と `confirmed_time` を別に保持する。右確認足は閉じた足のみ。原版どおり左側は厳密比較、右側は同値を許可する。旧Fib50用ConfirmedPivotとはこの同値規則が異なる。

### 執行状態（EA）

`WAIT_SIGNAL → ORDER_SENT → POSITION_OPEN → COOLDOWN → WAIT_SIGNAL`。応答不明・復旧不整合は `RECOVERY_BLOCKED`。構造状態の変化は `TW_transitions.csv`、候補の採否は `TW_signals.csv`、各M1判定はExpertsログに残す。

- 新しいM1足の最初のティックで1回だけ判断。週末等の欠損があれば、最後に閉じた実在M1足を次の利用可能ティックで評価する。起動前の古いシグナルは再発注しない。
- USDJPY完全一致、M1/M5、ロングのみ、最大1ポジション。他者のUSDJPY注文・保有があれば見送る。
- Equityの1%を予定損失予算とし、OrderCalcProfitで口座通貨換算。ロットを切り下げ、最小・最大・刻み・証拠金・最終損失を検査。
- `STOP_M1_WAVE2_LOW` がデフォルト。他に `STOP_M1_REVERSAL_LOW`、`STOP_M5_WAVE1_ORIGIN`。バッファ10 points、RR=1.2、クールタイム15分を入力化。
- SL/TP同時発注を優先。許可時のみ後付け保護へ移行。約定価格でTPとリスクを再計算し、保護失敗・約定後の予定損失予算超過なら既存ロングの決済を試みる。
- 約定時刻からクールタイム開始。判定済み足と注文計画を発注前にジャーナルへ保存し、応答不明を再送しない。RRも注文計画に保存して復旧する。
- Fib retracementとfib zoneは診断列のみ。スプレッド・ATR・ニュース・時間帯等の独自フィルター、トレーリング、分割利確は追加していない。

## 3. インジケーターとの一致・無効化確認

### 原版との差

2025-03-03～03-07の7,189判定を原版と修正版で逐次比較：**原版6件、修正版5件。共通5件は時刻とセットアップが一致。追加0件。**

除外された原版シグナルは **2025-03-07 19:20**。同じM5セットアップでM1反転安値割れが発生した後、原版では古い構造履歴を使った再探索が可能だった。修正版は失敗後のピボットだけで新しい下降構造を組み直すため、このREADYは成立しない。

証拠：[原版比較CSV](original_comparison.csv)、[原版比較ログ](native_results.log)、[最終テストの遷移ログ](real_ticks/TW_transitions.csv)。構造修正の詳細は [レビュー](review.md)。

### 修正版とEAの一致

- 3～4月Model=4：**61,774回のM1判定、READY 33件、不一致0件**。
- ビジュアルテスター：2,876回の判定、不一致0件。次の3例を実際のビジュアルテスター画面で確認した。

| サーバー時刻 | トリガー | Entry | SL | TP | 画面 |
|---|---|---:|---:|---:|---|
| 03-05 12:36 | Wave1 high | 149.459 | 149.372 | 149.563 | [例1](visual_final/window_live.png) |
| 03-06 00:55 | Wave1 high | 148.894 | 148.809 | 148.996 | [例2](visual_final/case_2.png) |
| 03-06 06:24 | Wave2 return high | 149.245 | 149.192 | 149.309 | [例3](visual_final/case_3.png) |

白い `EA LONG READY` と緑のインジケーターREADYが同じ境界時刻に表示される。大きなEA診断パネルは作っていない。画像は専用ビジュアルテスターのウィンドウを直接取得したもので、後から作った価格リプレイ画像ではない。

照合はEAの売買制御より前のREADY候補を対象にする。したがって保有中の見送り1件も「シグナル不一致」にはしない。各足で件数とM5セットアップID合計を照合し、候補CSVに全アンカー・発生時刻・確定時刻を記録している。[一致CSV](real_ticks/TW_parity.csv)、[自動監査](real_ticks/audit.json)。

3～4月の実データでもM5起点割れ64件、M5高値確定前の起点割れ15件、M1反転安値割れリセット33件、HL破棄41件の状態遷移を記録した。合成ケースだけでなく、履歴上でも無効化経路を通っている。

## 4. コンパイル・単体・執行検証

- EA・修正版インジケーター・検証スクリプト：**0 errors / 0 warnings**。このフォルダーの `*_compile.log` を参照。
- 構造テスト：**19/19成功**。右確認足、終値判定、M5起点割れ、反転安値割れ、HL割れ後の新HL、同じM5内部で新しいM1下降構造からの再開、将来の値動きによる過去READY不変を確認。
- 執行テスト：**19/19成功**。市場BUY、ロット切り下げ、1%予算、証拠金、ストップ距離、OrderCheckのtrue/0とfalse/0、復旧ジャーナル、後付け保護、保護失敗決済、約定後予算超過決済、無保護保有の計画欠落、応答不明時のブロックを確認。
- 後付け保護を強制するテスター専用入力でも5件発注。結果と候補は通常経路に一致。[後付け保護の監査](deferred_final/audit.json)、[ネイティブテスト詳細](native_final_runtime.log)。

## 5. バックテスト結果

設定：USDJPY、M1/M5、左右2/2、SL=Wave2 Low−10 points、RR=1.2、1%予定リスク、cooldown=15分、初期資金10,000 USD、レバレッジ1:100、MT5 build 6182、Model=4、追加遅延0。最適化なし。

### 2025-03-03～04-30

**注意：Model=4だが、一部生成ティックを含む。** 3月27日に実ティック欠落6分・不整合による破棄1,431分があり、全61,774分中1,437分が生成ティックへ置換された。MT5レポートには「100% リアルティック」と表示されるが、ログの置換警告を優先する。したがってこの2か月全体を純粋な実ティック検証とは呼ばない。

| 指標 | 結果 |
|---|---:|
| Trades | 32 |
| Win rate | 31.25% |
| PF | 0.5321 |
| Expectancy | −30.7516 USD / trade |
| Expectancy R | −0.3200 R / trade |
| Net profit | −984.05 USD |
| Max DD（Equity・MT5値） | 1,160.16 USD（11.43%） |
| Average win R | +1.2120 R |
| Average loss R | −1.0164 R |

Rは各取引の実約定価格から初期SLまでのOrderCalcProfit予定損失を分母に、実現純損益を割って計算した。手数料・swap・feeは、この口座のテスター記録ではすべて0。ライブでのコスト再現性を保証するものではない。

| 決済月 | 取引数 | 損益 USD |
|---|---:|---:|
| 2025-03 | 13 | −630.18 |
| 2025-04 | 19 | −353.87 |

READY 33件のうち32件発注、03-11 00:55の1件は保有中のため見送り。予定損失/Equityの最大値は約0.9991%。同時保有、重複、先読み、クールタイム、予定価格・SL/TP・ロットの自動監査違反0件。全32取引が決済済み。

[MT5レポート](real_ticks/tw_real_ticks.htm)、[取引別R](real_ticks/trades.csv)、[月別](real_ticks/monthly.csv)、[設定](real_ticks/default.set)、[品質警告と監査](real_ticks/audit.json)。

### 4月単独の実ティック確認

2025-04-01～04-30を初期資金10,000 USDから独立して再実行。**Model=4、5,490,716ティック、31,580判定、生成ティック置換警告0件、シグナル不一致0件。** データ品質の切り分けとして実施し、パラメータは同じ。

| 指標 | 結果 |
|---|---:|
| Trades / Win rate | 19 / 36.84% |
| PF | 0.6868 |
| Expectancy | −19.8837 USD / trade |
| Expectancy R | −0.1985 R / trade |
| Net profit | −377.79 USD |
| Max DD（Equity） | 447.68 USD（4.46%） |
| Average win R / loss R | +1.2158 R / −1.0234 R |

独立した4月の月別結果は19取引・−377.79 USD。3～4月連続運用の4月損益−353.87 USDとは開始Equityとロットが違うため、金額は一致しない。

[4月MT5レポート](april_real_ticks/tw_april_real_ticks.htm)、[監査](april_real_ticks/audit.json)、[取引別](april_real_ticks/trades.csv)、[月別](april_real_ticks/monthly.csv)。

## 6. 発見した問題と既知の制限

### Implementation bug

修正済み：M5高値確定と起点割れの処理順、M5高値確定待ち区間の起点割れ見落とし、M1失敗前の構造履歴の再利用、起点を割ったCHoCH足での再開始。通常矢印用のピボット生成でも現在の右確認足を除外した。原版が無効な経路を表示していた部分は一致を求めず、修正版同士で一致を確認した。

### Strategy definition issue

- 原版の「M5 Wave3が先行したら打切り」はM1 CHoCH済み・HL未確定という条件付き。M1 CHoCH前にM5高値を超えるケースまで除外する別条件は追加していない。この範囲を将来広げるなら戦略定義の変更として扱う。
- 構造が無効になった後の新規候補は破棄するが、既存保有を別の構造条件で途中決済しない。SL方式比較を保つため、保有後は選んだSL/TPに従う。
- 同一M5セットアップでは原版どおり最初のREADYを使用。最大240分・6000本/1800本の履歴窓を継承している。履歴欠損・履歴訂正・起動時の情報不足まで同一結果を保証するものではない。

### Execution / cost issue

- 3月27日のデータ置換。4月単独確認と区別する。
- 実現損失は予定1Rを超えることがある。今回も平均損失−1.0164Rであり、ギャップ・約定差・換算等を予定損失の制御で消すことはできない。1%の**実損失上限保証はできない**。
- 裸注文からの後付け保護中に停止・通信断が起きればSL/TP付与を保証できない。失敗時決済も通信状態に依存する。
- 実口座・デモフォワード、実保有を伴う端末再起動、実ブローカーの部分約定・通信断は未検証。ジャーナル復旧と失敗処理はネイティブモックで検証した。
- 旧Fib50 EAのジャーナルは新EAへ引き継がない。新しいMagic初期値を使用。排他は同一端末の同一Magic用で、別PC・別端末から同じMagicを使う運用は対象外。
- `USDJPY` 完全一致のみ。銘柄接尾辞には未対応。他者の保有や所有権不整合があれば新規を止める。
- 他の2種類のStopModeは実装済みだが、今回の成績比較では使っていない。

## 7. 次に検証すべき仮説

今回のコード・パラメータは変更せず、次段階として以下を切り分ける。

1. 「M5第3波の開始」の定義を、M1 CHoCH前のM5高値突破まで含めて厳密化すべきか。これはバグ修正ではなく戦略定義の確認。
2. 同じREADY集合に対し、Wave2 LowとM1 reversal lowとM5 originのSL方式だけを比較すると、損失分布がどう変わるか。
3. retracement/fib zone別の結果に再現性があるか。初版ではフィルター化しない。
4. 実際の口座手数料・遅延・通信断・再起動を加えて、注文管理と予定リスクが維持されるか。

## MT5で確認する手順

1. ナビゲータを更新し、EA `dev/mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long` を選ぶ。
2. ストラテジーテスターでUSDJPY・M1、上記期間、実ティック、10,000 USD、1:100に設定。
3. この報告の `.set` を読み込む。RR=1.2、左右2/2、StopMode=0、cooldown=15、Fib filter=falseを確認。
4. ビジュアルでの比較は `InpVerifyIndicator=true`。修正版インジケーターが同じチャートへ追加される。白いEA READY・緑のREADY・Entry・SL・TPを確認する。
5. 通常のチャートに修正版を表示する場合は `MultiTF_3WaveIn3Wave_Visualizer_Shared` を使う。原版v1.05との不一致1件は上記の意図した修正。
6. テスター専用の `InpVerifyIndicator` と `InpTestDeferredProtection` は実チャートではfalse。[通常チャート用の設定ファイル](default_chart.set) も保存した。実口座へのEA適用や自動売買の有効化は今回行っていない。
7. 再集計：`python tools/swing_structure/audit_three_wave.py real_ticks april_real_ticks visual_final deferred_final`。

今回の範囲はこの検証版まで。最適化・フォワード・ライブ稼働は実施しない。

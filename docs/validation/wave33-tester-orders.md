# 3波3波EAを過去データで売買させる

## 現行 v1.80：接続した逆①候補の取消と①手前へのTP延長

[v1.80 A設定](../../reports/presets/wave33-v180-A-M15-M5-orders.set) / [B設定](../../reports/presets/wave33-v180-B-M5-M1-orders.set)を使う。テスターを停止してEAを選び直し、新SETを読み込む。AはM5、BはM1。短期の確認用ビジュアルINIは [A](../../reports/backtest/wave33-v180-A-M15-M5-orders-visual.ini) / [B](../../reports/backtest/wave33-v180-B-M5-M1-orders-visual.ini)。XAUUSD+、2023.01.01〜2023.01.10、証拠金5,000 USD、RR入力1.0、注文ON。時刻はブローカー時刻のまま扱う。[今回のQA](../../reports/qa/w33v180/README.md)。

| 入力 | 既定値 | 動作 |
|---|---|---|
| `InpCancelConnectedOpposite` | true | 古い確定①終点を起点とする新しい逆①候補が出たら、古い未発注候補を終了 |
| `InpExtendTPToWave1` | true | RR基本TPが①極値の手前なら、①の少し手前まで利益方向へ延長 |
| `InpTPWave1BufferPoints` | 10.0 | ①と延長目標の間の追加余裕。pipsではなく銘柄のポイント単位 |

接続判定は同じ銘柄・時間足組、逆方向、共有する終点の日時と価格で行う。新しい逆①の終点確定は待たず、確定足ブレイクによる候補発生時に判定する。価格誤差の許容は半ポイント。古い候補が注文送信中・約定済みなら取り消さない。逆候補が後で失効しても旧候補は復活させない。赤い「見送り: 接続した逆①候補」と、tooltip・CSVの原因候補ID、共有終点、判断時刻を照合する。

TPはLONGなら①高値の下、SHORTなら①安値の上を目標とし、余裕は追加ポイント・現在スプレッド・1ティックの最大値。ティック単位で①の内側へ丸める。既に①以上へ届くTPや、延長目標より遠いTPは短縮しない。SLの根拠とリスク率によるロット計算は従来どおり。延長により実際の予定RRは入力RRより大きくなり得る。緑の「TP①手前」とtooltipに基本TP・最終TP・実RRを残す。計画時点で固定し、保有後の新しい①でTPを動かさない。

抵抗モード`CAP_TP`を明示選択した場合は、その上限をTP延長より後に適用する。`SKIP_IF_BLOCKED`は延長後の必要値幅を確認する。配布SETの抵抗モードは従来どおり`DISPLAY_ONLY`。CSVの`tp_wave1_buffer_points`は①手前目標を計算した際の余裕で、CAP後の最終TPまでの距離ではない。

約定済みの「保有後に逆①が確定→推定純損益が初めてプラスになったティックで決済」は`InpExitOnOppositeWave1=true`のまま併用する。候補の取消とは判定段階が異なる。通常チャートの注文禁止、全選択銘柄テストへの対応も維持する。以下の過去版は変更履歴。

## v1.71：気配値表示の全選択銘柄でも実行可能

v1.70の一括テストで出た `OnInit returned non-zero code 1` は、全選択銘柄のテストもMT5内部では最適化扱いなのに、EAがその実行文脈を拒否したため。v1.71は `InpAllowTesterBatchRuns=true`（既定）で許可する。発注には別途 `InpEnableTesterOrders=true` が必要で、通常の実口座・デモ口座チャートでは注文しない。[公式のOptimization=3](https://www.metatrader5.com/en/terminal/help/start_advanced/start)、[今回のQA](../../reports/qa/w33batch/README.md)。

テスターを停止し、EAを選び直して [v1.71 A設定](../../reports/presets/wave33-v171-A-M15-M5-orders.set) または [v1.71 B設定](../../reports/presets/wave33-v171-B-M5-M1-orders.set) を読み込む。AはM5、BはM1。全選択銘柄を使う場合はテスターで該当モードを選ぶ。各銘柄は同じ入力・別口座の独立したテストで、複数銘柄を同時保有するポートフォリオ検証ではない。

v1.71の単銘柄ビジュアル用INIは [A](../../reports/backtest/wave33-v171-A-M15-M5-orders-visual.ini) / [B](../../reports/backtest/wave33-v171-B-M5-M1-orders-visual.ini)。一括の工学確認では生成ティックで10銘柄・14約定/決済、コンパイルは0 errors / 0 warningsを確認した。2020年に履歴がない銘柄はこの修正後も実行できない。詳細と実ティック同期の制約は[QA記録](../../reports/qa/w33batch/README.md)。

一括パスは描画を実効OFFにする。目視照合は、結果から銘柄を一つ選び、通常の単銘柄・最適化無効・ビジュアルONで実行する。売買条件、RR入力、逆①確定後のプラス決済はv1.70のまま。

Common CSVは銘柄・入力と実行文脈のハッシュ・排他的な予約番号で分離し、同時実行や再実行で既存ファイルを上書きしない。`*_config.csv` の `resolved_run_tag`、`symbol`、`input_hash`、`optimization`、`effective_draw` を確認する。入力ハッシュには版・戦略・診断入力を含み、ランの表示名 `InpRunTag` は含めない。遠隔・クラウドエージェントのCSVは自動収集しない。今回のQAはローカルエージェントのみ。

`InpAllowTesterBatchRuns=false` で最適化扱いの実行を拒否できる。公開MQLフラグでは全銘柄テストだけを数値最適化から区別できないため、trueは最適化扱いのテスター全般を許可する。この修正が数値パラメータ探索を開始することはない。履歴がない期間・銘柄は別問題で、検証期間か銘柄を選び直す必要がある。

## v1.70：最初のFib到達前だけ①終点を延長

新しい [A設定](../../reports/presets/wave33-v170-A-M15-M5-orders.set) / [B設定](../../reports/presets/wave33-v170-B-M5-M1-orders.set) は `InpExtendWave1BeforeFib=true`。シグナル成立前・最初の最小Fib押し（既定38.2%）の観測前だけ、上位足の確定足で同方向の高安更新が続けば①終点を再追跡する。新しい終点も確定スイングを待つ。起点・候補ID・経過時間を保ち、旧②・古い下位転換条件を消去して判定し直す。既にFib到達した候補、成立済みシグナル、保有、失効は変更しない。

旧①・②・Fibは灰色で残し、延長中は灰色、新しく確定した①は青の「延長rN」で表示する。旧帯は延長開始で止め、新帯は新終点を知った時刻から描く。同じ上位足で新高安と旧Fib到達を両方観測した場合は先後不明として延長しない。`false`で延長だけをOFFにできる。

RR入力と逆①確定後のプラス決済は維持する。固定比較は **XAUUSD+、2020.10.01〜2020.11.18、5,000 USD**、AはM5、BはM1。ビジュアルINIは [A](../../reports/backtest/wave33-v170-A-M15-M5-orders-visual.ini) / [B](../../reports/backtest/wave33-v170-B-M5-M1-orders-visual.ini)。テスターを停止し、EAを選び直して新SETを読み込む。旧SETには延長入力がないため、比較にはv1.70 SETを使う。[検証結果と各5事例](../../reports/qa/w33ext/README.md)、[ユーザー画像2件の終点比較](../../reports/qa/w33ext/user_image_review.md)を参照。以下の過去版の仕様は変更履歴として残す。

## v1.61：リスクリワード比の設定

MT5テスターの「パラメータの入力」で **リスクリワード比（SL=1に対するTP倍率）** を変更する。キー名は既存の `InpRewardR` のままなので旧SETも引き継げる。0より大きい値を指定し、既定値は `1.0`。

| 入力値 | SL幅に対するTP幅 |
|---|---|
| 0.5 | 1:0.5 |
| 1.0 | 1:1 |
| 1.5 | 1:1.5 |
| 2.0 | 1:2 |

第2波の極値を根拠とするSLとリスク率によるロット計算はそのまま。LONG/SHORT、両時間足で共通のTP倍率として使う。価格は銘柄のティック単位に丸め、`CAP_TP` を選んだ場合は抵抗線手前までTPを短縮するため実際の予定RRは小さくなり得る。配布SETの抵抗モードは `DISPLAY_ONLY`。

逆①確定後のプラス決済 `InpExitOnOppositeWave1=true` は維持する。この途中決済では設定したTPより先に終了することがある。[A設定](../../reports/presets/wave33-v161-A-M15-M5-orders.set) / [B設定](../../reports/presets/wave33-v161-B-M5-M1-orders.set)。今回の変更は入力ラベルと版情報のみで、既存のRR計算・売買判定は変えていない。

## v1.60：逆方向の①が出た後の利益決済

新しい [Aプリセット](../../reports/presets/wave33-v160-A-M15-M5-orders.set) / [Bプリセット](../../reports/presets/wave33-v160-B-M5-M1-orders.set) は `InpExitOnOppositeWave1=true`。実際の保有開始後に逆方向の青い①の終点が確定したら黄色の「逆①：プラス決済待ち」を表示する。その認識時点で推定純損益がプラスならすぐに、それ以外は初めてプラスになる実行可能ティックで成行決済する。確定前のブレイク候補や、約定前から存在する反対①は使わない。

推定損益は現在のBid/Askによる価格損益、計上済み損益・手数料・費用、残存スワップ、推定決済費用を含む。推定決済費用は観測済みのエントリー手数料・費用から計算する。最終約定価格と将来費用は未知なので、実損益の厳密なプラスを保証する設定ではない。決済されるまで元のSL・TPは有効で、プラスへ戻らなければ従来どおりSL/TPで終了する。

CSVは `OPPOSITE_WAVE1_ARMED → OPPOSITE_CLOSE_REQUEST → OPPOSITE_CLOSE_ACCEPTED → EXIT` を追う。拒否は `OPPOSITE_CLOSE_REJECTED`、部分決済は `PARTIAL_EXIT` として残す。専用終了理由は `OPPOSITE_WAVE1_PROFIT`、ブローカーの理由は `exit_deal_reason`。黄色のEXITは実約定位置に描く。根拠となる反対候補ID・元の波の位置・EAが知った時刻はtooltipとCSVに残す。

`InpAuditOppositeExitTicks=true` は待機中の全評価ティックを `*_opposite_ticks.csv` に保存する検証用入力。通常プリセットはファイル量を抑えるためfalse。`InpExitOnOppositeWave1=false` で決済変更だけを無効化できる。①終点認識・エントリー・SL/TP・RRはv1.50と同じ。旧プリセットと結果は以下に履歴として残す。

`Wave33VisualVerifier` は、MT5ストラテジーテスターの過去データで発注・SL/TP決済を行える。下記の専用プリセットは `InpEnableTesterOrders=true`。既存の診断専用プリセットは注文OFFのまま残す。

**v1.50**では、上位足の確定終値がFib61.8%より深く戻った未成立候補を終了する。今回はこの1要因を比較し、RR1、W1余地0.25R、下位認識方式2などは維持する。実行中のテスターには反映されないので、停止してEAを選び直し、下表のv1.50 SETを読み込んで再実行する。v1.40 SETには新しい入力がないため、v1.50の比較には使わない。[v1.50の検証資料](../../reports/qa/wave33_fib_close_20261021/README.md)を参照。旧版の[固定10事例](../../reports/qa/wave33_entry_room_20261021/final_case_comparison/README.md)は履歴として残す。

## MT5画面で開始する

1. MT5で **Ctrl+R** を押し、ストラテジーテスターを開く。
2. EAに `dev\mql\Experts\Wave33VisualVerifier.ex5` を選ぶ。見つからなければナビゲータのエキスパートを右クリックして「更新」。
3. v1.70の固定比較は銘柄 **XAUUSD+**、期間 **2020.10.01〜2020.11.18**。短区間で操作を試す場合も、開始日が違うと蓄積したスイングが変わり、同じ波の再現は保証しない。モデルは **全ティック（リアルティックに基づく）**、最適化は無効、**ビジュアルモードON** にする。ブローカーの実際の銘柄名を選ぶ。今回の保存データはリアルティックがなく生成ティックへ代替されたため、執行品質の評価は未実施。
4. 下表の時間足を選び、「パラメータの入力」で右クリック → 「読み込み」から専用 `.set` を読み込む。AとBは別々に試す。
5. `InpEnableTesterOrders=true`、`InpExtendWave1BeforeFib=true`、`InpExitOnOppositeWave1=true`、`InpRiskPercent=1.0`、`InpRewardR=1.0`、`InpStrictWaveLifecycle=true`、`InpLowerRecognition=2`、`InpMinWave1RoomR=0.25`、**`InpRejectDeepFibClose=true`、`InpRejectDeepFib=false`** を確認して「スタート」。今回の比較は初期証拠金5,000 USD、レバレッジ1:100。
6. 再生を一時停止し、青①第1波 → オレンジ②押し・戻り → ENTRY → SL/TPと実際の売買を照合する。テスターの「結果」でも約定と決済を確認できる。

| パターン | テスター時間足 | 読み込む注文ONプリセット | テスター設定ファイル |
|---|---|---|---|
| A：M15第3波 × M5転換 | M5 | [v1.70 A注文ON](../../reports/presets/wave33-v170-A-M15-M5-orders.set) | [v1.70 Aビジュアル設定](../../reports/backtest/wave33-v170-A-M15-M5-orders-visual.ini) |
| B：M5第3波 × M1転換 | M1 | [v1.70 B注文ON](../../reports/presets/wave33-v170-B-M5-M1-orders.set) | [v1.70 Bビジュアル設定](../../reports/backtest/wave33-v170-B-M5-M1-orders-visual.ini) |

両方とも確定終値による `PIVOT_BREAK`、抵抗線は表示のみ、RR1:1。1%は各注文のSLまでの損失予算で、lot stepに合わせて切り下げる。最低ロットで予算を超える場合やブローカーの注文条件を満たせない場合は見送り理由を残す。開始後にスイングを蓄積するため、区間冒頭はすぐに注文が出ないことがある。ブローカーの銘柄名が `XAUUSD` と異なる場合は実際の銘柄名を選ぶ。

`InpRejectDeepFibClose=true` は、Aでは **M15終値**、Bでは **M5終値**を固定したW1のFib境界と比較する。61.8%を厳密に超えた場合だけ `FIB_CLOSE_TOO_DEEP` で候補を終了し、61.8%ちょうどは許容する。形成中の足は使わず、ヒゲだけの超過はこの条件では除外しない。画面には「見送り: M15終値の押し xx.x%」またはM5の表示を残す。

従来の `InpRejectDeepFib=false` はそのまま維持する。こちらの入力はW2の最深高安による別の除外条件であり、今回ONにしない。終値除外のOFF/ONを比較するときは **`InpRejectDeepFibClose` だけ**を変える。W1確定待ち中の上位終値違反はW1確定時に初めて判断し、元足・終値確定・判断可能の3時刻を記録する。成立済みシグナルや保有ポジションを後からこの条件で取り消さない。

`InpLowerRecognition=2`（`NORMALIZED_OR_SIMPLE`）は、確定スイングを整理した逆構造に加え、同じ第2波の確定極値→最初の反対側pivot→新しい終値突破という単純反応も観測する。CSVでは `NORMALIZED_COUNTERTREND` と `SIMPLE_REACTION_BREAK` を区別する。単純反応を厳密な下位1→2→3の成立とは呼ばない。`0` は旧来の厳密な逆構造、`1` は整理した逆構造のみの比較用。

`InpMinWave1RoomR=0.25` は、発注可能なAsk/Bidから固定した青①終点までの符号付き距離を、SL幅=1Rで割った余地の下限。足りなければ `WAVE1_ROOM_TOO_SMALL` で見送り、ENTRYは描かない。これは動画の確定ルールではなく、遅い位置の約定を比較するための仮定であり、`0` で無効にできる。余地が正でも①終点やTPへの到達は保証しない。

紫の候補線は `R`＋短いハッシュで対応付け、元の時間足・高値/安値・元日時・確定して知った時刻（known）・今回採用した時刻（adopted）をtooltipとCSVで追える。青①終点までの余地は紫の抵抗候補と分けて表示する。線は有限で履歴を残し、大きな情報パネルは初期値OFF。

ユーザー画像を照合するときは画像と同じ銘柄・期間を使う。「初動を逃したため終了」の候補は後から復活させない。下位調整の所属と初回進行の定義は[ライフサイクルの仮定](../../knowledge/experiments/2026-10-21-wave33-lifecycle-repair.md)。`InpStrictWaveLifecycle=false` は旧挙動の診断比較用で、配布SETは `true`。

## INIは起動設定の補助として使う

通常の操作は上のCtrl+R手順を使う。同梱 `.ini` は、MT5公式の `/config:設定ファイルの絶対パス` 起動で使う補助設定。現在の配置 `MQL5\Experts\dev\mql\Experts\Wave33VisualVerifier.ex5` を指す。[MT5公式の起動設定](https://www.metatrader5.com/en/terminal/help/start_advanced/start)

v1.50同梱INIは今回の比較に合わせ、両方とも `Symbol=XAUUSD+`、`Deposit=5000`。Aは2018.02.01〜2019.01.17、Bは2019.01.02〜2019.01.17。別ブローカーでは実際の銘柄名と履歴を使う。旧版INIは履歴として残す。

`ExpertParameters` の専用 `.set` は、使用する端末の `MQL5\Profiles\Tester` に同名で配置する。別の端末へ持ち出す場合も対応する `.set` を配置し、EAの配置に合わせて `Expert` を修正する。`ShutdownTerminal=0` により、テスト終了後も端末を残す。

通常の実口座・デモ口座チャートでは、注文ONプリセットを読み込んでもEA内部のテスター専用ガードにより注文しない。`.ini` も通常チャートの自動売買を無効のままにする。v1.70以前は最適化モードを拒否したが、v1.71では冒頭の一括テスト用入力に従う。

全候補・発注・約定・決済は `Terminal\Common\Files` の `wave33_v150_A_M15_M5_orders*_events.csv` または `wave33_v150_B_M5_M1_orders*_events.csv` に保存する。同じタグがあればEAが別名を付けるため、過去CSVを上書きしない。終値違反には `fib_close_bar_time`、`fib_close_at`、`fib_close_known_at`、`fib_close_price`、`fib_close_ratio` を追加記録する。同じタグの `*_upper_bars.csv` は受理した上位足の全OHLCと確定・既知時刻を保存し、違反のなかった候補も照合できる。詳しい読み方は [目視照合手順](wave33-v1-visual-review.md) を参照。

## 更新版の実行確認

v1.50は[専用QA資料](../../reports/qa/wave33_fib_close_20261021/README.md)で、上位足終値除外のOFF/ONを比較する。対象はXAUUSD+、Aが2018.02.01〜2019.01.17、Bが2019.01.02〜2019.01.17、証拠金5,000 USD。成立・失効・見送りを全候補で追い、利益を使った条件最適化は行わない。7コンパイルが0 errors / 0 warnings、既存399＋新128＝527項目PASS。Aは208候補でOFF72SIGNAL/42約定、ON42SIGNAL/21約定。Bは45候補でOFF27SIGNAL/17約定、ON20SIGNAL/12約定。全約定は決済まで確認した。平均RはAが-0.25459→-0.32343、Bが+0.07750→+0.10673。Aでは平均Rが悪化しており、今回の除外を収益改善策として採用済みとはしない。以下のv1.40の数値と混同しない。

過去のv1.40ではXAUUSD・2025.01.06〜2025.01.18をネイティブMT5テスターで実行し、Aは**3約定・3決済**、Bは**30約定・30決済**を確認した。全候補はAが19件、Bが59件で、SIGNALはそれぞれ5件・41件。これは発注・決済の動作確認であり、利益や動画一致の合格判定ではない。[A原本イベント](../../reports/qa/wave33_entry_room_20261021/final_engineering/20261021_151408_14185e95/a_orders_smoke/events.csv)、[B原本イベント](../../reports/qa/wave33_entry_room_20261021/final_engineering/20261021_151408_14185e95/b_orders_smoke/events.csv)。

同じ最終QAではEAと5ハーネスの6コンパイルがすべて0 errors / 0 warnings、ハーネス計399項目（100＋28＋96＋156＋19）がPASS。[最終エンジニアリング証拠](../../reports/qa/wave33_entry_room_20261021/final_engineering/20261021_151408_14185e95/)。固定画像10事例では、維持対象3件の約定と遅い3件の余地不足による見送りを確認した。残る4件は早い認識・未成立の妥当性を含めて要目視であり、全事例が修正完了したとは扱わない。

自動スモークは非ビジュアル実行。専用INIと上の画面操作はビジュアルON。過去のbuild 6230検証ではテスター内のPNG保存要求が成功を返しても画像が生成されなかったため、通常チャート上の**記録イベント再生画像**をテスター直接キャプチャと区別する。実テスター画面と動画・ユーザー画像の照合は目視レビューに残る。旧版の結果・SETは履歴として残す。

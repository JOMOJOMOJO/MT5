# 3波3波EAを過去データで売買させる

`Wave33VisualVerifier` は、MT5ストラテジーテスターの過去データで発注・SL/TP決済を行える。下記の専用プリセットは `InpEnableTesterOrders=true`。既存の診断専用プリセットは注文OFFのまま残す。

現在の配布版は **v1.30**。古いW1/W2を後の下位転換へ使い回さない修正を含む。実行中のテスターには反映されないので、停止してEAを選び直し、下表のv1.30 SETを読み込んで再実行する。`InpStrictWaveLifecycle=true` を確認する。[修正内容・画像3件の検証](../../reports/qa/wave33_lifecycle_20261021/README.md)

## MT5画面で開始する

1. MT5で **Ctrl+R** を押し、ストラテジーテスターを開く。
2. EAに `dev\mql\Experts\Wave33VisualVerifier.ex5` を選ぶ。見つからなければナビゲータのエキスパートを右クリックして「更新」。
3. 銘柄は **XAUUSD**、期間は **2025.01.06〜2025.01.18**、モデルは **全ティック（リアルティックに基づく）**、最適化は無効、**ビジュアルモードON** にする。
4. 下表の時間足を選び、「パラメータの入力」で右クリック → 「読み込み」から専用 `.set` を読み込む。AとBは別々に試す。
5. `InpEnableTesterOrders=true`、`InpRiskPercent=1.0`、`InpRewardR=1.0` を確認して「スタート」。初期証拠金は10,000 USD、レバレッジ1:100が同梱設定。
6. 再生を一時停止し、青①第1波 → オレンジ②押し・戻り → ENTRY → SL/TPと実際の売買を照合する。テスターの「結果」でも約定と決済を確認できる。

| パターン | テスター時間足 | 読み込む注文ONプリセット | テスター設定ファイル |
|---|---|---|---|
| A：M15第3波 × M5転換 | M5 | [v1.30 A注文ON](../../reports/presets/wave33-v130-A-M15-M5-orders.set) | [v1.30 Aビジュアル設定](../../reports/backtest/wave33-v130-A-M15-M5-orders-visual.ini) |
| B：M5第3波 × M1転換 | M1 | [v1.30 B注文ON](../../reports/presets/wave33-v130-B-M5-M1-orders.set) | [v1.30 Bビジュアル設定](../../reports/backtest/wave33-v130-B-M5-M1-orders-visual.ini) |

両方とも確定終値による `PIVOT_BREAK`、抵抗線は表示のみ、RR1:1。1%は各注文のSLまでの損失予算で、lot stepに合わせて切り下げる。最低ロットで予算を超える場合やブローカーの注文条件を満たせない場合は見送り理由を残す。開始後にスイングを蓄積するため、区間冒頭はすぐに注文が出ないことがある。ブローカーの銘柄名が `XAUUSD` と異なる場合は実際の銘柄名を選ぶ。

ユーザー画像との比較では銘柄を **USDJPY** に変更し、A・M5で同じ2016年の期間を使う。修正版は「初動を逃したため終了」の候補を後から売買しない。下位調整の所属と初回進行の定義は[明示した仮定](../../knowledge/experiments/2026-10-21-wave33-lifecycle-repair.md)。`InpStrictWaveLifecycle=false` は旧挙動の診断比較用。

## INIは起動設定の補助として使う

通常の操作は上のCtrl+R手順を使う。同梱 `.ini` は、MT5公式の `/config:設定ファイルの絶対パス` 起動で使う補助設定。現在の配置 `MQL5\Experts\dev\mql\Experts\Wave33VisualVerifier.ex5` を指す。[MT5公式の起動設定](https://www.metatrader5.com/en/terminal/help/start_advanced/start)

`ExpertParameters` の専用 `.set` は、この端末の `MQL5\Profiles\Tester` に同名で配置済み。別の端末へ持ち出す場合は、その端末の `MQL5\Profiles\Tester` にも対応する `.set` を同名で配置し、EAの配置に合わせて `Expert` を修正する。`ShutdownTerminal=0` により、テスト終了後も端末を残す。

通常の実口座・デモ口座チャートでは、注文ONプリセットを読み込んでもEA内部のテスター専用ガードにより注文しない。`.ini` も通常チャートの自動売買を無効のままにする。最適化モードはEAが拒否する。

全候補・発注・約定・決済は `Terminal\Common\Files` の `wave33_v130_A_M15_M5_orders*_events.csv` または `wave33_v130_B_M5_M1_orders*_events.csv` に保存する。同じタグがあればEAが別名を付けるため、過去CSVを上書きしない。詳しい時刻・見送り理由は [目視照合手順](wave33-v1-visual-review.md) を参照。

## 更新版の実行確認

v1.30で上記のXAUUSD区間をネイティブMT5テスターで実行し、Aは1約定・1決済、Bは9約定・9決済を確認した。自動スモークは非ビジュアル実行。専用INIはビジュアルONで、画面操作の手順でもONにする。コンパイル0 errors / 0 warnings、ハーネス計215項目PASS。[結果と描画の証拠](../../reports/qa/wave33_lifecycle_20261021/README.md)。旧v1.20の結果・SETは履歴として残す。

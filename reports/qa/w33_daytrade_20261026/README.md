# Wave33 DayTrade v1.90: 24時間上限と段階SL

状態：**ビルド・静的確認済み／native QAは起動後ユーザーの呼びかけまで結果未確認**。これは実装・注文処理の検証であり、年間収益性の合格ではない。

ユーザーからの注文設定の質問で既存結果を参照：純粋判定52項目はPASS。nativeは買い・売り各1件の実約定を確認したが、全体は `fixture_order_send` の失敗226件を含み **FAIL（250項目）**。fixture失敗の原因照合は保留で、native全体の合格ではない。テスターの再実行はしていない。ユーザーが動かしている最新設定は `tester_orders=false` だった。以下の注文ONプリセットを読み込むか `InpEnableTesterOrders=true` に変更し、新しい実行を開始する必要がある。

## 新しいEA

- [Wave33DayTradeVerifier.mq5](../../../mql/Experts/Wave33DayTradeVerifier.mq5) / 同名EX5。既存の `Wave33ChopDiagnostic` v1.85や原版EA・共有既存headerは変更しない。
- [純粋な判定](../../../mql/Include/Wave33Visual/DayTrade.mqh)と[注文・描画・ログ](../../../mql/Include/Wave33Visual/DayTradeExecution.mqh)を新規モジュールに分離した。
- LONGは決済側Bid、SHORTはAskの最大到達値を追跡。1Rは実際の平均約定価格と初期SLの距離で固定する。分割約定の会計とposition数量が一致し、入口注文が完了してからSL段階を有効にする。
- 初期設定は+2Rで建値、+3Rで+1R、+4Rで+2R、その後1R刻み。固定TP・部分利確は使わない。`InpStepSL=false` は同じ24時間・TPなしで初期SLを維持する比較用。
- 段階を記憶し、価格が戻ってもSLを緩めない。取引tick丸め、stops/freeze、注文確認を通し、実positionのSLを観測してから `STEP_SL_CONFIRMED` とする。要求受理だけで確定扱いにしない。
- 約定の最初のmillisecondから24時間経過後、最初の取引可能なtickで全残量を成行決済。満了前の逆①利益決済とSLは維持し、二重の決済要求を避ける。決済要求の拒否・部分約定は残量会計を確認して再試行する。
- `InpCloseBeforeWeekend=true` は、銘柄の週次セッションで24時間以上の休場に入る最終セッションの5分前から手仕舞いし、新規を止める。銘柄時刻を使い、金曜の固定JST時刻は仮定しない。祝日・臨時休場やquote不在は週次APIだけで完全に分からず、厳密な24時間以内の約定を保証しない。

デフォルトの `InpEnableTesterOrders=false` は診断のみ。trueでもテスター以外では発注・決済・SL変更をしない。既知高安帯によるTP見送り／CAP_TPは固定TPを必要とするため、この専用EAでは `DISPLAY_ONLY`・`InpSkipPriorLevelRetest=false` を要求する。旧RR・①TP入力は診断上の参照だけで、実注文のTPにはならない。

## 描画とログ

固定TPは描かない。ブローカーがSL変更を確認した時刻から赤いSLを新しい位置へ動かし、以前のSLは有限の点線で残す。ラベルの詳細には確認時刻・初期R維持を記録する。左上パネルは追加しない。

共通Filesの `<run_tag>_daytrade.csv` に、初期risk固定、段階到達、SL変更要求／拒否／確認、時間決済要求／受理／拒否、全決済を保存する。既存のevents/raw_deals CSVも残す。時間決済は `TIME_LIMIT_24H`、週末前は `WEEKEND_SESSION_CLOSE`。価格建値は手数料・swapを含む損益ゼロを保証しない。

## コンパイルと確認の範囲

[EAログ](compile/Wave33DayTradeVerifier.log)、[純粋判定テストのビルド](compile/Wave33DayTradePolicyTests.log)、[native harnessのビルド](compile/Wave33DayTradeHarness.log)はいずれも0 errors / 0 warnings。MetaEditorのプロセス終了code1は既存compile helperがログを優先して扱う挙動であり、MQL警告件数とは分ける。

純粋判定テストはLONG/SHORT、1Rでは移動なし、2R→建値、3R→1R、stage飛び越し、pullback待機、決してSLを緩めない、tick丸め、24時間境界、週末境界、不正入力を用意した。まだnative実行結果を確認したとは扱わない。

[native harness](../../../mql/Experts/tests/Wave33DayTradeHarness.mq5)は、同じproduction EAと純粋moduleを含み、実テスターでLONG/SHORT各1件の発注・SL変更・拒否時の再試行・時間決済・数量保存・競合close lockを検査する。送信経路を確実に通すため、SLテストには一時的なlag2.5Rと人工的なMFEを、時間決済には24時間分古くしたfixture時刻を明示的に使う。価格・数量・約定・SL変更はnative APIを使うが、実際に24時間保有した証拠や戦略の成績ではない。部分約定・週末閉場の実brokerケースの網羅は別確認。

起動は[prepare-smoke.ps1](prepare-smoke.ps1)で隔離portableを準備し、[launch-smoke.ps1](launch-smoke.ps1)で1回だけ行う。起動後は待機・再実行・集計をせず、`latest.json` にPIDと `LAUNCHED_AWAIT_USER_RESUME` を残す。ユーザーから声がかかってからnativeテスト結果を収集する。既存端末の停止や設定変更は行わない。

## ユーザー用設定

テスターで `dev\\mql\\Experts\\Wave33DayTradeVerifier` を選び、次のプリセットを読み込む。これらは注文ON・描画ONのテスター用で、通常チャートの注文ガードは維持される。

- [M15×M5・段階SL](../../../presets/wave33/Wave33DayTrade_v190_A_Visual.set)：チャートM5を推奨。
- [M5×M1・段階SL](../../../presets/wave33/Wave33DayTrade_v190_B_Visual.set)：チャートM1を推奨。
- 比較用：[M15×M5・SL据置](../../../presets/wave33/Wave33DayTrade_v190_A_SLFixed_Visual.set) / [M5×M1・SL据置](../../../presets/wave33/Wave33DayTrade_v190_B_SLFixed_Visual.set)。共通条件はTPなし・24h上限・逆①利益決済あり。

R段階の2/1/2は未検証の初案。利益採用や最適値とは扱わない。[提案・評価順序](../../../knowledge/experiments/2026-10-26-wave33-daytrade-exit-plan.md)。

参照：[OrderSendは受理だけでは約定確認にならない](https://www.mql5.com/en/docs/trading/ordersend)、[取引イベントの順序・内容](https://www.mql5.com/en/docs/event_handlers/ontradetransaction)、[銘柄別の週次取引セッション](https://www.mql5.com/en/docs/marketinformation/symbolinfosessiontrade)。

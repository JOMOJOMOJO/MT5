# Wave33 v1.85: 半分利確と建値SL

[固定仕様](../../../knowledge/experiments/2026-10-26-wave33-scaleout-plan.md)に従う実装・約定処理の確認。利益最適化や実運用への昇格とは区別する。

## 動作

`Wave33ChopDiagnostic` の `InpScaleOut=true` が新しい動作。基本RR目標と、判断時点で固定した①極値の少し手前の目標を近い順に並べる。近い方で初期約定数量の半分を決済し、その実約定を確認してからSLを実際の建値へ移す。残量のTPは遠い方。SHORTは上下を反転する。`InpScaleOut=false` は従来の一括TP延長へ戻る。

①手前の余裕は既存の `InpTPWave1BufferPoints`、スプレッド、1ティックの最大値。エントリー後の未来の波へ目標を付け替えない。抵抗による明示的なTP制限は優先し、二つの目標を作れない場合は一括決済にまとめる。

ロット刻みにより半分は切り捨てとなる。どちらかが最小ロット未満なら、ロットを増やさず手前の目標で全量決済する。部分約定・再試行でも最初の半分を維持し、残りを毎回半分にしない。建値変更がストップ距離等で拒否された場合は元のSLを維持し、理由を残して再試行する。価格の建値は手数料やスワップまで含めた損益ゼロではない。

既存の「逆①確定後にプラスなら決済」を維持し、同じ残量へ二重に決済注文を出さない。基本RR、当初SL、リスク率、①の接続両側見送り、Fib終値除外、往復/上位高安帯の設定を同時に調整しない。

## 証拠

- [ネイティブQAの範囲と失敗記録](NATIVE_QA.md)、[最終6ケース](native_latest.json)、[独立CSV監査](native_event_audit.json)。
- [変更後のリスク表示26検査](display_latest.json)。注文を発行しない通常チャートの合成OHLCで、建値SL/分割不可TPの変更時刻、通常SL/TPの元時刻、繰り返し配置と有限引出線を確認し、PNGも目視確認した。実取引のスクリーンショットとは区別する。
- [コンパイル](compile/Wave33ChopDiagnostic.log)、[原版・共通計算保持と最終hash](final_verification.json)。
- [固定年間比較](../../backtest/runs/wave33_v185_2020/PLAN.md)と[実行結果](../../backtest/runs/wave33_v185_2020/README.md)。
- [完了時の85検査](completion.json)で、年間4条件完了、現行source/EX5/headerの凍結hash、原版保持、ユーザー用45入力プリセット、10事例と成果物リンクを照合した。年間の固定監査23,112項目もPASS。

実約定の確認環境はRETAIL_HEDGING。positionとsymbolを指定する共通API経路を使うが、ネッティング口座でネイティブ検証したとは扱わない。注文はテスター内のみ。生成ティックによる機能検証を実ティックの執行品質証明と呼ばない。

## チャートとログの確認

テスターで `dev\\mql\\Experts\\Wave33ChopDiagnostic` を選び、M15×M5ならM5、M5×M1ならM1を表示する。`InpEnableTesterOrders=true`、`InpScaleOut=true`、`InpDraw=true`、ビジュアルモードON。新しい実行を開始し、既に動いている旧バイナリのテストと混同しない。

金色の `TP1 半分` が近い目標、緑のTPが残量の最終目標。半分約定後の赤い `SL 建値` と、元のSLの有限の点線を確認する。分割不可は `TP 全量`。詳細な理由・時刻・数量は同じsetup IDのCSVで追う。

共通Filesの `<run_tag>_scaleout.csv` に PLAN → VOLUME_FROZEN → TP1_TOUCH → CLOSE_REQUEST/ACCEPTED → TP1_FILLED → BE_REQUEST/CONFIRMED を記録する。拒否・保留・再確認・分割不可・最終TPへのギャップは別イベント。`<run_tag>_raw_deals.csv` が実dealの数量・利益・commission・swap・feeの原本。最終Rは部分利確を合算し、当初の全数量SLリスクを分母とする。

テスターが最終TPを先に全量約定した場合、途中の半分利確を捏造しない。注文OFFは目標の診断描画のみで、架空の約定や建値SL変更を記録しない。

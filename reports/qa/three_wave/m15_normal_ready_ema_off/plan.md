# 通常READY・EMA OFF：実行仕様

前回通常READYの固定setから変更するのは `InpUseEMAFilter=true → false` だけ。M1/M5 2/2ヒゲ、通常READY、SkipHL=false、reversal low−10points、RR1.2、15分クールタイム、1ポジションを維持する。表示用EMAは前回同様OFF。M15は分類・診断のみで、売買フィルターにしない。

## 2つの母集団

1. 全READY shadow：売買制約を見る前のREADYイベントで、その最初の利用可能tickのAskを記録。独立した仮想ポジションを追跡し、重複保有・クールタイムで削らない。SL/TP丸めは本体と同じ。SLは観測Bidでギャップを反映、TPは指定価格で評価。spreadを含む価格Rで、手数料・swap・数量・証拠金は含まない。未決済はEND_CENSOREDとして残す。
2. 実行可能リプレイ：前回売買ソースの控えに観測呼び出しだけを挿入し、注文制約と実約定をそのまま実行。EMAだけOFF。shadowと混ぜず、実売買純損益Rと価格Rを分ける。

どちらもMFE/MAE・到達率の比較用経路は初期SLまたは24時間まで。shadowには別途決済までのMFE/MAEも保存。経路未完了は到達率の分母から分ける。

## 実行キュー

- 2025-01-01〜01-10：売買本体／研究観測版のCSV一致チェック。
- 2025-01-01〜07-01：既知期間6か月。
- 2024-07-01〜10-01：既知期間3か月。
- 2025年前半の同設定再実行：再現性チェック。

両期間はOOSではない。以前の実ティック欠損・生成ティック置換の制約も結果で明示する。自動検査はset差分1項目、前回139候補とのID・時刻一致、shadow網羅、Entry Ask一致、pivot確定時刻、M15独立Python計算との一致、売買本体hash不変を対象にする。検査に失敗したらキューを停止する。

## ファイル

- `TW_ready_shadows.csv`：全READYの独立仮想損益。
- `TW_signals.csv`・`TW_deals.csv`・`TW_exits.csv`：実行可能リプレイ。
- `TW_ready_paths.csv`：実約定に対応する24時間経路。
- `TW_M15_environment_USDJPY_260922331.csv`：READYと実約定のM15固定スナップショット。
- `batch_status.json`：RUNNING / FAILED / TESTS_COMPLETE_AWAITING_ANALYSIS。
- `batch_stdout.log`・`batch_stderr.log`：ローカル実行ログ。

ユーザーの指定により、MT5キュー起動後に対話ターンを終了する。結果のカテゴリ集計・EMA ON比較・summary.mdは、ユーザーから再開の声掛けを受けてから行う。起動時点ではテスト成功や結果は未確認。

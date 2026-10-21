# 汎用化QAのテスト終端履歴を修正

前回9本QAの3本目で、標準レポートとobserver CSVの約定件数が不一致となった。
deal 14/15はテスト終了時の強制決済で、CSVだけに欠損。EAが取引を停止した証拠とは分けて扱う。

- [診断・r2計画](../../reports/qa/portable_audit_20261009_r2/plan.md)
- [旧失敗結果](../../reports/qa/portable_audit_20261008/runs/20261008_175938_81b17f66/status.json)
- [変更差分](../../reports/qa/portable_audit_20261009_r2/observer.diff)
- [凍結manifest](../../reports/qa/portable_audit_20261009_r2/manifest.json)
- [コンパイル](../../reports/qa/portable_audit_20261009_r2/preflight/20261009_153207_3ad9f4f6/status.json)

研究専用PortableDealQuoteAuditで、テスター終了時だけ全約定履歴を取得。
最終quote時刻とtester終端の差を診断出力し、従来の全deal照合は緩めない。
売買ロジックへのデータ経路はなく、Entry/SL/TPやリスク設定の変更はない。
旧成果物は上書きせずr2パッケージに分離。本番EAとユーザーの既存変更はhash保持。
Python9テスト合格、4ソースcompile 0/0。修正のMT5有効性は再実行で確認する。

今回の教訓は[既存知見](../../knowledge/lessons/mt5-signal-preservation-and-report-completion.md)に関連する。
原因確定前に新しい公開用seedを増やさず、前回の[汎用化知見](../../content/seeds/2026-10-08-trend-definition-and-portability.md)を維持する。

## 再実行結果の確認

[r2結果](../../reports/qa/portable_audit_20261009_r2/review.md)：9本のうちハーネス合格、2本目の旧版照合で停止。
売買7件の時刻・価格・volume・SL/TPは一致し、差はEURUSDのswap計+0.05 USDのみ。
CSVは14/14約定で一致したが、問題のdaily_timerは未実行。修正成功・QA全体完了とは報告しない。
費用差の元原因はまだ確定していない。既存の厳密監査を緩めず、同時点の費用条件で対にした比較を次の切り分けとする。
今回の結果照会ではMT5を再起動せず、コード・売買条件も変更していない。

## 次の進め方の提案

[提案書](../../reports/qa/portable_audit_20261009_r2/next_steps_proposal.md)に、同条件の旧/新対照、売買と費用の個別監査、狙いと実装の対応確認、一要因だけの次研究という順序を保存。
既存18設定・日足固定版の不採用を維持。今回は相談への提案であり、MT5の追加起動や売買ロジック変更は行っていない。

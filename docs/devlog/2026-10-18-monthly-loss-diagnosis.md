# 全10条件の月次と負け方を再集計

2026-10-18。PF>1の12シナリオ全体を対象に、取引数と月次安定性を調べる要望に対応。旧EA・研究結果を変更せず、`tools/entry_research/monthly_review/`を追加した。

12シナリオ2,874取引、順序重複を除いた10条件2,666取引、同通貨・方向・時刻もまとめた2,406時点を区別。月次決済損益と含み損益を含む評価額変化、無取引と未取得、元候補と実行数を分離した。事後の負け方と事前の4環境軸を比較し、保存取引を除いた場合に失う勝ちと悪化する月も出力した。フィルタ付き売買ルールの再実行は未実施。

レビューで月境界の翌月新規約定費用の扱いを修正し、新規約定0月と決済0月を区別。実データの月次数値は変わらず、8テストと全20口座の損益照合が合格。9表をCSV/Parquet/DuckDBへ保存し、ローカルブラウザーで図の描画も確認。正本は`final/`、先行検証出力は保持。2026の探索使用なし。

判断と次の仮説は[研究レビュー](../../knowledge/experiments/2026-10-18-monthly-loss-diagnosis-review.md)。数値は[正本レポート](../../reports/research/monthly_loss_20261018/final/report.md)、検算は[delivery.json](../../reports/research/monthly_loss_20261018/qa/delivery.json)、再実行は[README](../../tools/entry_research/monthly_review/README.md)。

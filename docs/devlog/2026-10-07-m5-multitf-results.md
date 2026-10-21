# M5 × M15/H1/H4観測バッチの完了確認

ユーザーの「おわった」に対して結果を読み取り、追加MT5を起動せず分析した。
[完了status](../../reports/qa/m5_multitf_diagnostics_20261007/runs/20261007_134859_995aab81/status.json)
[レビュー](../../reports/qa/m5_multitf_diagnostics_20261007/runs/20261007_134859_995aab81/review/summary.md)
[永続メモ](../../knowledge/backtests/2026-10-07-m5-multitf-diagnostic-review.md)。

4run完了、3runで既存売買結果との完全一致、因果時刻・M15分類一致を確認。
1,666候補/217実取引、2つの1分内両側到達をshadowの成績から除外。未特定後段見送り4件は推測せず明記。
独立したreviewスクリプトで出力CSVから再集計し、元の統計CSVとの完全一致を検査。
環境別グラフを作成・目視確認。凍結ソース/プリセットのハッシュ再検査合格。

重要な所見はH4条件の採用ではなく、年別・raw/実行母集団での方向不一致と、83.3%のspread抵触。
売買EA、Shared、パラメータ、フィルターは変更していない。既知期間診断からの採用を見送り、追加最適化も行わない。

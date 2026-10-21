# volume切下げ再計算：QA完了

- 研究専用の単独変更。旧版/OFF/ON×3銘柄とharness×3銘柄、全12本合格。
- 3ソースコンパイル0 errors / 0 warnings、MT5計算harness計48項目、事前Python監査11項目合格。
- 旧版/OFF一致。ON受理planすべて予算内、同一plan内で減量のみ。本番EA/Shared・凍結原本hash維持。
- USDJPY4回復plan、損益差+27.95 USD。ただし3件は後続取引との入れ替え、1件は同じ実取引。件数49のまま、PF0.847で収益性不合格。
- EURUSD36件−505.68 USD、XAUUSD55件+73.63 USD、いずれも変更なし。
- 全銘柄で単独毎月20件を満たさない。既知2023年1〜3月・生成tick・USD口座の機能QA。
- 研究版既定OFF、本番適用・新しい最適化・長期/OOS開始なし。このサイクルを閉じる。

[固定計画](../../reports/qa/portable_risk_adjustment_20261012/plan.md)

[個別取引までの結果・検証範囲](../../reports/qa/portable_risk_adjustment_20261012/runs/20261012_221125_4ece6118/review/summary.md)

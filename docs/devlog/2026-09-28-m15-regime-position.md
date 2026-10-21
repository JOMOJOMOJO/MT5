# M15方向と構造内位置の記述研究

119候補・476 RR結果を固定し、確定pivotのUP/DOWN/RANGEと構造内LOW/MID/HIGHを付与。breakの方向・経過分・距離と未来30/60/120分ラベルは独立列にした。売買EA/Shared/Entry/SL/TP不変。

構造範囲は最新2高値max・2安値min、位置は三等分固定。構造外24件を黙って範囲内扱いせず、raw値と範囲外フラグ、範囲内のみの診断集計を併記した。

[summary.md](../../reports/qa/three_wave/m15_regime_position_research/summary.md) に結果、[tables.md](../../reports/qa/three_wave/m15_regime_position_research/tables.md) に4RR全表。DOWN_MID/HIGHは両期間で正だったが少数。UP_LOWの一部は構造安値の下で、最後のbreakがbearishだった。方向単独の押し目解釈を避ける。

途中切断・未来改変・反復再生、元損益全列とhash不変、90月別カテゴリセルの網羅を確認。既知データ・生成tick制約を継承し、採用や閾値探索なし。外部記事seedは未作成。頻度は増えず月20回要件未達のまま。

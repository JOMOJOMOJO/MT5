# READY画像ブラインド研究：実装前確認

ユーザー指定に従い、今回は画像生成前にデータ源・未来リーク対策・MT5再実行要否を整理した。画像生成・抽出・採点は未実施。本番EA/Shared/Entry/SL/TPの変更なし。

- [生成計画と事前点検](../../reports/qa/three_wave/ready_blind_chart_200/blind_chart_generation_plan.md)
- [117特徴との対応](../../reports/qa/three_wave/ready_blind_chart_200/feature_gap_analysis.md)

既存RR1.2母集団2083件を維持し、RR1比較の2082件とは混ぜない。40年×TF組のOHLCを確認し、2083×4候補窓で指定足数不足0。主要構造confirmed timeにEntry後のもの0件。これは画像の未来不変性監査完了を意味しない。

MT5再実行は不要と判断。形成中上位足の完成OHLCを流用せず、closed timeとavailable_atの両方で切断する。既存Sharedは左厳密・右同値許容のpivotであり、初期会話の左右厳密ルールを無断で再導入しない。

描画関数にはラベル列を渡さず、private対応表とpublic画像を分離。過去ラベルを扱ったこの分析担当がそのままブラインド採点者にはならない。未知OOSという表現を避け、200件の画像仮説診断として評価設計を固定する。

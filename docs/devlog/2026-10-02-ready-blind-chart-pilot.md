# READY画像ブラインド研究：20件試作と監査完了

## 範囲

2016〜2025各年20件の候補200件を固定し、各年2件の20候補だけraw/annotatedを生成。合計40PNG。残り180件は未生成。ChatGPT採点、ラベル結合、損益分析、特徴追加、売買EA/Shared変更は実施していない。

## 成果物

- [v2仕様](../../reports/qa/three_wave/ready_blind_chart_200/blind_chart_generation_plan_v2.md)
- [20件の監査](../../reports/qa/three_wave/ready_blind_chart_200/generation_audit_20.md)
- [画像QA](../../reports/qa/three_wave/ready_blind_chart_200/image_qa_20.md)
- [公開manifest](../../reports/qa/three_wave/ready_blind_chart_200/public_sample_manifest_20.csv)
- [固定プロンプト](../../reports/qa/three_wave/ready_blind_chart_200/prompt_template.md)
- [生成・監査コード](../../tools/swing_structure/build_blind_chart_pilot.py)
- [最終検証・記録コード](../../tools/swing_structure/finalize_blind_chart_pilot.py)

## 確認結果

6560表示足、189構造注釈の時刻監査合格。20件×2版でprefix切断、未来OHLC改変、結果列改変のpixel hash一致。公開40PNGのmetadataは空でIHDR/IDAT/IENDのみ。200件の固定seed再計算一致、重複0。全40枚を目視し、原寸の追加確認も実施。本番ファイルは作業前後hash不変。

## 試作で修正した不具合

内部 `break_time/choch_time` は足開始だが、EAのCSVSignalはTF秒を加えた閉じた時刻を書き出す。初回の注釈側でこれを開始時刻と解釈し、11個のCHoCHの終値照合に失敗した。CSV writerを確認して解釈を直し、40 CHoCH全件照合・20件の全監査を再実行した。raw画像hashと抽出集合は修正前後で不変。v1計画よりv2仕様を正本とする。

return highは11候補でログに存在しないため省略、9候補では確認して描画。未来や仮の構造点で補完しなかった。

再利用する判断は [研究メモ](../../knowledge/experiments/ready-blind-chart-pilot-20261002.md) に記録。品質確認用画像から売買スコアを付けておらず、今回の20件を「判定済み」とはしない。

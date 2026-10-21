# READY画像ブラインド：試作20件の品質ゲート

## 判断と証跡

raw20・annotated20の生成監査と目視QAに合格。固定200候補は2016〜2025各年20、試作は各年2。今回180件へ拡張しない。相場の採点・損益の結合は未実施で、優位性の評価結果ではない。

- [生成監査](../../reports/qa/three_wave/ready_blind_chart_200/generation_audit_20.md)
- [描画・入力分離仕様](../../reports/qa/three_wave/ready_blind_chart_200/blind_chart_generation_plan_v2.md)
- [画像QA](../../reports/qa/three_wave/ready_blind_chart_200/image_qa_20.md)

## 再利用する知見

1. 構造内部の時刻とCSVへ出力した時刻を同じと仮定しない。このEAのCSVSignalはCHoCHの内部bar timeにTF秒を加える。CSV値を再び足開始と扱うと、注釈が1足ずれる。writerまで確認する。
2. 因果時刻の不等式だけでなく、該当足の実価格と突破条件も照合する。今回この照合が誤った時刻解釈を検出した。
3. 描画関数にはラベルを渡さず、相対OHLCと検証済み点だけの契約にする。未来改変とラベル改変に対するpixel hash不変性を全件で確認する。
4. rawを共通ベースとしannotatedはoverlayに限定すると、ラベルだけでなくレイアウト差による比較の混入も検証できる。
5. 年均等抽出は母集団の年構成比と異なる。後の統計では年均等評価と母集団加重評価を区別する。まだ集計しない。
6. 全年は既知研究データであり、画像スコアが未判定でも戦略の未知OOSとは呼ばない。採点者へprivate対応表・既存研究成績・もう片方の画像を渡さない。

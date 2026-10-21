# READY固定：RR1/RR1.2の選択と特徴量追加

## 判断

NO_PROMOTION。今回の5パターンは、年をまたぐ正期待値と月20件の頻度を両立しない。Entry/SL/本番EAは維持した。

## 根拠

- [詳細・仕様・制限](../../reports/qa/three_wave/ready_rr_choice/summary.md)
- [実行集計](../../reports/qa/three_wave/ready_rr_choice/execution_summary.csv)
- [TP選択効果の分離](../../reports/qa/three_wave/ready_rr_choice/same_selection_rr_attribution.csv)
- [最終レビュー](../../reports/qa/three_wave/ready_rr_choice/final_review.json)

2016〜2025の同じEntry/SL、2082共通ラベルで、1R未達SL1189件、1R到達後1.2R前SL81件、1.2R到達812件。固定RR1/1.2の平均Rは−0.167/−0.168で、勝率の増加だけでは損益を修復できなかった。

2018〜2025の過去学習・翌年評価で、時刻/曜日/spread直接特徴を除去。111特徴LightGBM、29特徴LightGBM、tsfresh192追加、波形PCA+logistic、訓練内tsaugノイズ追加の5固定比較。最高のtsfreshも53件、+0.021R、PF1.040、月0.55件、月ブロック95%区間−0.221〜+0.247R。2025が主なプラスで、2020/2021/2023は負。

同じ53選択候補をRR1.2固定なら+0.063R。RR1への変更で負けを救ったのは1件、勝ち利益を縮めたのは21件。モデルによる見送りと利確変更の効果を分離して評価する必要がある。見送りなしの補助診断も5種全て負。

## 再利用する注意点

- 明示spreadを外しても、Ask Entry由来Rや価格位置への間接影響は残る。
- 生成tickと年が交絡するので、実tick部分の好成績だけでシミュレータ原因と断定しない。
- tsaugは独立した取引事例を増やさない。ノイズ後にも元ラベルが成立する保証はない。
- 全年は既知研究データ。未使用OOSではない。
- RR1の新TP時刻はM1到達足終端を保守的上限とする。正確なMT5注文再現ではない。
- 同分SL/TP両到達は両RRの和集合5件を除外、未完了4件も別扱い。モデル評価1647件、全候補記述2082件を混ぜない。

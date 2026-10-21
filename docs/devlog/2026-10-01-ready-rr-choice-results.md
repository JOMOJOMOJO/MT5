# READY固定のRR選択研究：完了レビュー

売買EA・Shared・Entry・SLは変更せず、RR1/RR1.2/見送りを過去年だけで学習した5パターンを確認した。新しい閾値探索や本番採用は行わない。

- [計画・全結果](../../reports/qa/three_wave/ready_rr_choice/summary.md)
- [最終QA](../../reports/qa/three_wave/ready_rr_choice/final_review.json)
- [同じ選択候補のTP効果](../../reports/qa/three_wave/ready_rr_choice/same_selection_rr_attribution.csv)
- [再現用レビュー](../../tools/swing_structure/review_ready_rr_choice.py)
- [継続判断](../../knowledge/experiments/ready-rr-choice-20261001.md)

学習は完了し、全5モデルの再学習一致、8364波形窓、75内部分割の因果順序、Entry/SL/元RR1.2ラベルの全件一致、EA/Sharedハッシュ不変を確認。グラフ3枚も確認した。

2082共通ラベル中、1R到達後1.2R前のSLは81件（元1270敗の6.38%）。RR短縮の救済利益と勝ち側の利益縮小がほぼ相殺された。モデル評価2018〜2025で最高のtsfreshも実行53件、+0.021R、PF1.040、月0.55件。同じ53件を全てRR1.2にすると+0.063Rで、利確選択自体は改善していなかった。

売買EAへの反映は見送り。今回だけでシミュレータ依存を断定しない。時刻/スプレッド除去と同時に目的変数も変えているため、前回とのAUC差を除去効果だけとして説明しない。

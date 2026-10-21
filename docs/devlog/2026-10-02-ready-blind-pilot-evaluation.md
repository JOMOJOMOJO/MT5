# ブラインド判定20件の初回開封

ユーザーの「判定して」を受け、固定済み提出20件を元候補と実結果へone-to-oneで結合した。事前固定のA/B/C、continuation scoreの上位10/20/30%、decile、AUC、Spearman、年別を集計。LightGBM比較、閾値探索、画像追加生成、売買変更は実施しない。

- [結果](../../reports/qa/three_wave/ready_blind_chart_200/judgments/submission_ea6df8ad8ba7bad5/evaluation/summary.md)
- [全20件の対応](../../reports/qa/three_wave/ready_blind_chart_200/judgments/submission_ea6df8ad8ba7bad5/evaluation/judgments_with_outcomes.csv)
- [評価コード](../../tools/swing_structure/evaluate_blind_chart_pilot.py)
- [研究判断](../../knowledge/experiments/ready-blind-pilot-evaluation-20261002.md)

原文、固定200候補、公開画像、元候補表のhashを確認。private20のID対応は固定200とも一致。AUCは勝ち負け99ペアの直接比較でも一致。散布図を確認済み。

全体9勝11敗、平均−0.01860R、PF0.9667。A=2勝3敗、B=2勝4敗、C=5勝4敗。主AUC0.43434、上位20%=4件2勝2敗、+0.09459R。最上位2件は両方SL。小標本で画像スコアの正の選別力は確認できず、C採用や反転判定も行わない。

この20件は今後「結果開封済み」。未判定180件を後で評価するときは、この20件を未使用検証に混ぜない。実際の採点モデル・プロンプト・チャット履歴・画像版は添付JSONだけから確認できないため、その運用上の制限も結果に記載した。

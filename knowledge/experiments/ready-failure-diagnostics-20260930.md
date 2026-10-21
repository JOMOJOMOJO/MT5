# READYを維持した負け方の分解

## 固定母集団

2025年1〜6月93件、2024年7〜9月46件の通常READY、EMA OFF。全shadow候補であり実行可能取引だけに絞らない。Entry/SL/TPと元の損益ラベルは保持。

## 再利用する判断

「上がるが利確まで届かない」と「ほとんど追随しない」を分ける。MFEは決済までとし、利確後の伸びを勝敗診断へ混ぜない。負け83件中46件は0.3R未満でSL。ALMOST_TPは15件にとどまり、抵抗距離との関係も期間で方向が逆転した。

次に診断する価値があるのは、①Wave1の値幅ではなく陽線率と途中逆行の組み合わせ、②古いセットアップと高値試し反復の組み合わせ。組み合わせ自体の有効性は未検証。数値閾値を売買条件に採用しない。

浅い木でも既知データに適合する。今回の期間間balanced accuracyは約0.20/0.21で定数予測0.25を下回った。木の閾値は持ち出さない。

139件の親IDは別だが、近接相場や重複する将来価格経路による依存は残る。2024のALMOST_TPは3件しかなく、再現性判定には不足。

## 証拠

[summary](../../reports/qa/three_wave/ready_failure_diagnostics/summary.md) / [全候補](../../reports/qa/three_wave/ready_failure_diagnostics/ready_failure_analysis.csv) / [期間方向](../../reports/qa/three_wave/ready_failure_diagnostics/period_direction_comparison.csv) / [木の診断](../../reports/qa/three_wave/ready_failure_diagnostics/decision_tree_diagnostic.txt)

# 通常READY ML追加診断のレビュー

バックグラウンド学習はCOMPLETE_AWAITING_REVIEWで正常完了。固定4仕様、過去だけの較正、30回月内ラベル対照、1000回月block bootstrap、年次簡易実行診断を実施。学習EA/Shared変更なし。

全117較正はBrier0.2361まで改善（一定0.2371）が、期待R>0の実行33件は−0.155R。R回帰は全体337採点で−0.108R、PF0.821だが、2024年30採点+0.240R/PF1.547、2025年31採点+0.258R/PF1.587。改善は後半年に限定され、月20回要件には届かない。

29特徴較正の39件は全体+0.173R/PF1.365だが、2020年1件/2024年9件/2025年29件で、2025は−0.019R。再現性ある優位性とは判定しない。時刻/Spread除外はAUC0.503となり、構造だけの一貫した識別を確認できなかった。

元の1648予測との完全一致、最終年4再学習一致、全候補因果時刻、各モデルの同一1656候補、除外候補の学習/採点非混入、各年リプレイ占有/クールタイム、EA/Sharedハッシュ不変をレビューした。グラフを確認し、集計の小標本・年偏りをsummaryへ補足。追加最適化や本番採用なし。

[summary](../../reports/qa/three_wave/ready_generated_tick_deep_review/summary.md) / [固定計画](../../reports/qa/three_wave/ready_generated_tick_deep_review/plan.md) / [独立監査](../../reports/qa/three_wave/ready_generated_tick_deep_review/feature_label_audit.md)

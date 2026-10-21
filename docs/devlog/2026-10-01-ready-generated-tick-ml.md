# 通常READY: 生成tick許容で2016〜2025年を再分析

ユーザー指示に従い、実tick限定の採用基準を研究用だけ変更。同じM1足がSL・TPの両方に到達した4件と未完了4件を全2091候補から除き、2083件を使用した。除外情報は将来の品質ラベルであり、Entry特徴量やライブフィルターではない。

既存117特徴量とモデル設定を維持。2016〜17初期学習、2018〜25の8年次拡張検証で1648件を評価。LightGBM AUC=0.544427、Brier=0.237617（学習勝率一定=0.237074）。固定確率binはいずれも平均Rが負。件数拡大で弱い識別傾向は見えたが正期待値化には至らない。

2083件のM1最初バリアとテスター結果が一致。特徴量のprefix/未来変更QA、40モデル再学習一致、EA/Sharedハッシュ不変を確認。2024/25の既存特徴量は再利用。モデル前処理の高fragmentation警告は研究DataFrameのcopyで修正。レポートの追加tabulate依存は除去した。MT5の再起動、売買条件変更、閾値最適化は行わなかった。

証拠: [summary](../../reports/qa/three_wave/ready_generated_tick_ml/summary.md)、[audit](../../reports/qa/three_wave/ready_generated_tick_ml/audit.json)、[除外前監査](../../reports/qa/three_wave/ready_generated_tick_ml/exclusion_preflight.csv)。

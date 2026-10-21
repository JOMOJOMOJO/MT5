# 収集後・モデル評価前の固定プロトコル

2026-09-30。収集180件。実tick開始2024-06-06、40警告日。Entry〜決済の全日で警告がなく実tick開始以降の82件だけを教師あり学習のtargetにする。その他98件はtester_outcomeを保存するがtargetは欠損。生成tick由来の勝敗を実tick確定ラベルとして扱わない。日単位の保守的除外であり、個々のraw tickを独立再取得した検証ではない。

指定4foldは維持。学習30件未満、片クラス5件未満、test片クラスなしは評価不能と記録してスキップ。foldを組み替えて成功率を上げない。test開始前15分embargo、train決済時刻がembargo境界以降ならpurge。同じ親IDのtrain/test重複も除外。

全特徴量は保存し、モデルには意味の重複を減らした事前の明示allowlistを使用。Entry価格/絶対価格/時刻ID/ラベル/決済後経路/品質判定フラグは入力禁止。相対距離と比率、経過時間、構造カテゴリ、server時刻の周期だけ使用。欠損中央値、標準化、カテゴリone-hotはtrainだけでfit。

- Logistic: L2, C=0.1, max_iter=3000
- Tree: depth=2/3/4をすべて報告、min_samples_leaf=15
- LightGBM: 100trees, learning_rate=.03, num_leaves=7, max_depth=3, min_child_samples=15, reg_lambda=5, subsample=1, colsample=1, deterministic=true, seed=0, threads=1。early stoppingやパラメータ探索なし。
- train TP比率による定数予測を基準にする。
- 確率binは指定の0.35/0.40/0.45/0.50/0.55/0.60。
- permutation importanceはtest AUC、20反復seed固定。H1/M15のグループ置換も保存する。結果を再学習の特徴選択へ戻さない。
- SHAP未導入のため今回は省略し、permutationを優先。
- KMeans k=2〜6を全報告。trainだけで補完・標準化、seed=0,n_init=20。seed1/2とのARIで初期値安定性を確認。outcomeでkを選ばない。成立foldが1つなら期間安定性は評価不能。

2024年は既知研究期間を含む。時間順testを完全未使用OOSとは呼ばない。多特徴・小標本、ラベル経路の重複を明記。未検証条件の採用なし。主に残るtestは2024年11〜12月30件であり、4fold再現性を主張できない。

# 生成tickを許容した通常READYの機械学習研究

## 結論

生成tickを許容することで学習対象を2083件まで増やせた。LightGBMには弱い識別傾向があるが、確率予測の誤差は全期間で単純な学習勝率予測より改善せず、前回固定の確率binはすべて平均Rが負だった。「モデルで正期待値の取引群を作れた」という結果ではない。今回はフィルターや売買EAへ反映しない。

LightGBMで繰り返し寄与したのはサーバー時刻(hour_cos)、spread/ATR、spread/Rなど。H1最寄り抵抗距離やWave1の加速も一部の年で寄与した。ただしpermutation importanceは勝ち方向を示す指標ではない。生成tickのスプレッド仕様を学んだ可能性があるため、そのまま市場の優位性や特定セッションの効果と解釈しない。

## 対象と除外

2016〜2025年USDJPY、通常READY、EMA OFF、M1/M5ヒゲpivot 2/2、SL=M1 reversal low−10points、RR1.2を固定。既存MT5収集結果を再利用し、2023は履歴再取得後のBybit実行を使用。Vantageや再実行の候補を重複加算していない。売買EA・Shared変更なし、追加MT5起動なし。

全2091候補のうち、Entry分からExit分までのいずれかのM1足でLow<=SLかつHigh>=TPとなる4件を除外。未完了4件を別扱いとし、学習対象は2083件。Entry/Exit分の足全体で判定する保守的な方法で、除外のための将来情報はモデル特徴量に使用しない。

この除外は将来の結果を見たデータ品質処理であり、ライブで適用できる売買フィルターではない。除外後成績を実際の売買成績とは呼ばない。実tick限定の旧結果も保持する。

| year | all_candidates | dual_touch | censored | other_excluded | n | tp_rate | expectancy_R | pf |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2016 | 228 | 0 | 0 | 0 | 228 | 0.434 | -0.053 | 0.908 |
| 2017 | 207 | 0 | 0 | 0 | 207 | 0.382 | -0.166 | 0.734 |
| 2018 | 189 | 1 | 0 | 0 | 188 | 0.388 | -0.168 | 0.735 |
| 2019 | 228 | 1 | 1 | 0 | 226 | 0.381 | -0.205 | 0.691 |
| 2020 | 214 | 0 | 2 | 0 | 212 | 0.368 | -0.207 | 0.680 |
| 2021 | 198 | 1 | 1 | 0 | 196 | 0.311 | -0.338 | 0.525 |
| 2022 | 242 | 0 | 0 | 0 | 242 | 0.426 | -0.092 | 0.848 |
| 2023 | 192 | 0 | 0 | 0 | 192 | 0.385 | -0.196 | 0.703 |
| 2024 | 180 | 1 | 0 | 0 | 179 | 0.419 | -0.116 | 0.813 |
| 2025 | 213 | 0 | 0 | 0 | 213 | 0.394 | -0.170 | 0.736 |

## 固定した評価方法

- 前回と同じ117特徴量・モデル設定。M15/H1の構造・位置・高安pivotを結ぶ線の傾き/価格距離も含む。
- 2016〜2017を初期学習とし、2018〜2025を1年ずつ前進検証。各年の学習には前年までのみ使用。
- 年境界の15分embargo、決着前ラベルの除外、親ID重複排除。補完・標準化・カテゴリ変換は学習側でfit。
- 閾値探索・最適化・売買条件採用はしていない。ランダム分割なし。既知期間なので未使用OOSとは呼ばない。
- 各年・各モデルの再学習40回は予測値1e-12以内で一致。各年の特徴量構築でprefix再計算・未来価格変更への不変性・M15ネイティブ表示との一致を監査。

## モデル結果

| model | n | roc_auc | pr_auc | brier |
| --- | --- | --- | --- | --- |
| LIGHTGBM | 1648 | 0.544 | 0.410 | 0.238 |
| LOGISTIC_L2 | 1648 | 0.524 | 0.417 | 0.258 |
| TRAIN_PREVALENCE | 1648 | 0.480 | 0.378 | 0.237 |
| TREE_D2 | 1648 | 0.532 | 0.407 | 0.242 |
| TREE_D3 | 1648 | 0.524 | 0.398 | 0.252 |
| TREE_D4 | 1648 | 0.517 | 0.392 | 0.262 |

LightGBMの年別AUCが0.5を上回ったのは7/8年、Brierが学習勝率一定予測より良かったのは4/8年。pooled AUCだけで年を跨ぐ再現性を判断しない。

親ID単位で500回再抽出したpooled AUCの95%区間（年を跨ぐ相場変化を完全に表す区間ではない）:

| model | parent_blocks | replicates | auc_low | auc_high |
| --- | --- | --- | --- | --- |
| LIGHTGBM | 1648 | 500 | 0.515 | 0.574 |
| TRAIN_PREVALENCE | 1648 | 500 | 0.451 | 0.509 |

| year | roc_auc | pr_auc | brier |
| --- | --- | --- | --- |
| 2018 | 0.483 | 0.378 | 0.254 |
| 2019 | 0.528 | 0.425 | 0.240 |
| 2020 | 0.519 | 0.392 | 0.237 |
| 2021 | 0.600 | 0.387 | 0.214 |
| 2022 | 0.508 | 0.421 | 0.250 |
| 2023 | 0.569 | 0.444 | 0.234 |
| 2024 | 0.621 | 0.532 | 0.234 |
| 2025 | 0.554 | 0.426 | 0.236 |

### 売買候補そのものの成績

| scope | n | tp_rate | expectancy_R | pf |
| --- | --- | --- | --- | --- |
| ALL_SETTLED_BEFORE_EXCLUSION | 2087 | 0.390 | -0.168 | 0.736 |
| ALL_ELIGIBLE | 2083 | 0.390 | -0.169 | 0.735 |
| WF_TEST_2018_2025 | 1648 | 0.385 | -0.185 | 0.714 |
| WF_PREVIOUS_REAL_TICK_VERIFIED | 294 | 0.401 | -0.152 | 0.761 |

Rは保存済みshadowのAsk Entry/Bid決済から計算。生成tickのスプレッド・約定順序モデル依存は残る。手数料・スワップ等を含む口座純損益ではない。1ポジション/クールタイムの実行成績とは区別する。

## 頻度

全120か月の除外後候補平均は17.36件/月、最少6件、月20件以上は37/120か月。これは全shadow候補で、実行可能取引数ではない。候補段階ですでに毎月20回を保証しないため、モデルによる絞り込みで頻度目標を満たすとはいえない。

## LightGBMの特徴量診断

下表は各テスト年で特徴を入れ替えた際のAUC低下。正負が年によって変わる特徴は安定した根拠としない。テスト結果で特徴を選び直して再学習する処理は行っていない。

| feature | positive_years | negative_years | mean_auc_drop |
| --- | --- | --- | --- |
| hour_cos | 8 | 0 | 0.022 |
| spread_m1_atr | 7 | 1 | 0.018 |
| h1_nearest_resistance_R | 6 | 1 | 0.008 |
| hour_sin | 6 | 2 | 0.004 |
| nearest_resistance_R | 6 | 2 | 0.003 |
| window10_entry_position | 5 | 3 | 0.003 |
| wave1_acceleration | 7 | 1 | 0.003 |
| spread_R | 8 | 0 | 0.003 |
| window5_net_return_atr | 4 | 4 | 0.003 |
| window10_upper25_fraction | 5 | 1 | 0.002 |
| m15_nearest_resistance_R | 4 | 4 | 0.002 |
| wave1_second_half_speed_atr | 4 | 3 | 0.002 |
| wave1_high_close_fraction | 6 | 2 | 0.001 |
| m15_atr_state | 3 | 1 | 0.001 |
| h1_nearest_support_R | 5 | 3 | 0.001 |

## 出力

- all_candidates.csv: 全候補・除外理由・既存の実tick品質フラグ・特徴量。
- excluded_candidates.csv / exclusion_preflight.csv: 除外の内訳。
- bar_first_touch_audit.csv: M1足で最初に触れたバリアとテスター結果の整合。
- yearly_statistics.csv / monthly_statistics.csv: 件数・成績。
- walkforward_predictions.csv / walkforward_metrics.csv / walkforward_folds.csv: 予測・年別成績・分割。
- probability_bins.csv / annual_probability_bins.csv: 前回固定の確率bin別成績と頻度。最良閾値は選択しない。
- real_tick_subset_sensitivity.csv: 実tick品質確認済み部分だけでの感度確認。
- lightgbm_importance.csv / feature_stability.csv / period_feature_statistics.csv: 特徴量別診断。
- decision_tree_diagnostic.txt: 深さ2の診断木（数値閾値は学習側標準化単位）。
- annual_model_metrics.png / yearly_counts.png: グラフ。

## 制限

生成tickでのSL/TP順序の曖昧さを4件取り除いても、実Ask・スプレッド・ギャップ・滑りを完全には再現しない。短時間で片側だけに到達したケースは除外しない。同じ親波や近接時刻の候補は独立ではなく、2091候補を独立2091取引と見なさない。結果に基づく採用・優位性確立の主張はしない。

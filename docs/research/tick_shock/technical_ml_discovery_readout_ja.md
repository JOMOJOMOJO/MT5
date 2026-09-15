# Tick-Shock Technical ML Discovery：結果の説明

判定：`NO_EA_CANDIDATE_UNDER_PREREGISTERED_GATE`。今回の依頼どおり**分析まで**。EA作成・変更・MT5再実行はしていません。

## 結論

1～4月の11,230 episodes、486特徴量を使い、2～4月の9,602 episodesで時系列評価しました。6モデル系統×3予測対象×2特徴量版×5距離×3期間＝540組を実行しました。頻度調整を含む3,240設定のうち、各月200件以上は1,996設定、その中で合計損益がプラスは3設定。しかし各月プラスの設定は0でした。

**「全部マイナス」ではありません。ただし月を跨ぐ安定性とコスト余裕が弱く、採用条件は満たしませんでした。** 事前ルールに従い5～6月へは進めていません。5～6月は過去の実験で観測済みなので、今後使っても完全未使用OOSではありません。

## 1. 合計損益がプラスだった設定も開示

以下は実Bid/Askに含まれるspreadに加え、**仮想の追加往復0.2 pip**を控除した1R固定のoffline損益です。実commissionの測定値ではありません。0.2 pipには、未観測commission・追加slippage等への感度を見る意味があります。

| family | target | variant | geometry | policy | trades | expectancy_r | pf | maxdd_r | worst_month_ev | top5_removed_total_r |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RANDOM_FOREST | NET_R | FULL486 | 3 | FREQUENCY_200 | 844 | 0.00823 | 1.01980 | 20.42242 | -0.05564 | 1.99071 |
| RANDOM_FOREST | NET_R | FULL486 | 3 | PERCENTILE_300 | 985 | 0.00144 | 1.00345 | 23.85341 | -0.05614 | -3.53959 |
| EXTRA_TREES | NET_R | FULL486 | 5 | ABS_0 | 857 | 0.00113 | 1.00468 | 16.25712 | -0.04588 | -4.00535 |

geometry index1/2/3/4/5は、それぞれ0.5/0.75/1.0/1.5/2.0 ATRです。上表は開示用であり、採用候補への差し替えではありません。

| candidate_id | month | trades | expectancy_r | pf | total_r |
| --- | --- | --- | --- | --- | --- |
| RANDOM_FOREST__NET_R__FULL486__3__FREQUENCY_200 | 202502 | 204 | -0.05564 | 0.87541 | -11.35126 |
| RANDOM_FOREST__NET_R__FULL486__3__FREQUENCY_200 | 202503 | 308 | 0.02037 | 1.05024 | 6.27355 |
| RANDOM_FOREST__NET_R__FULL486__3__FREQUENCY_200 | 202504 | 332 | 0.03623 | 1.08911 | 12.02713 |
| RANDOM_FOREST__NET_R__FULL486__3__PERCENTILE_300 | 202502 | 229 | -0.05614 | 0.87337 | -12.85671 |
| RANDOM_FOREST__NET_R__FULL486__3__PERCENTILE_300 | 202503 | 348 | 0.01420 | 1.03521 | 4.94131 |
| RANDOM_FOREST__NET_R__FULL486__3__PERCENTILE_300 | 202504 | 408 | 0.02288 | 1.05525 | 9.33415 |
| EXTRA_TREES__NET_R__FULL486__5__ABS_0 | 202502 | 375 | -0.01251 | 0.95155 | -4.69127 |
| EXTRA_TREES__NET_R__FULL486__5__ABS_0 | 202503 | 281 | 0.05295 | 1.25455 | 14.87954 |
| EXTRA_TREES__NET_R__FULL486__5__ABS_0 | 202504 | 201 | -0.04588 | 0.82014 | -9.22184 |

プラス3設定の通貨・週別依存、上位5件除外、0～1pip感度、cluster/day bootstrapは `positive_pooled_*.csv`。多数比較後に選ばれたプラスなので、独立した利益証明ではありません。

## 2. モデル別：合計EVが最も良い設定

| family | target | variant | geometry | policy | trades | expectancy_r | pf | worst_month_ev |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ELASTICNET | NET_R | FULL486 | 4 | PERCENTILE_200 | 938 | -0.00482 | 0.98476 | -0.04259 |
| EXTRA_TREES | NET_R | FULL486 | 5 | ABS_0 | 857 | 0.00113 | 1.00468 | -0.04588 |
| LIGHTGBM | NET_R | FULL486 | 4 | PERCENTILE_300 | 1027 | -0.01505 | 0.95383 | -0.02594 |
| LOGISTIC | NET_R | FULL486 | 2 | FREQUENCY_100 | 759 | -0.01351 | 0.97219 | -0.05823 |
| RANDOM_FOREST | NET_R | FULL486 | 3 | FREQUENCY_200 | 844 | 0.00823 | 1.01980 | -0.05564 |
| SHALLOW_TREE | WIN | FULL486 | 5 | ABS_0.1 | 788 | -0.01874 | 0.92638 | -0.06368 |

別表`model_family_comparison.csv`は最悪月EVを重視した順位です。順位基準を混同しません。NET_Rを選んだLOGISTIC行はRidge回帰、ELASTICNET行はElasticNet回帰。WIN/TP_FIRSTではそれぞれL2/ElasticNet Logisticです。XGBoostは未導入、SHAPはLightGBM標準機能を使用しました。

## 3. 月別安定性を重視した診断モデル

Extra Trees・net R直接回帰・448特徴量・TP=SL=2ATR・学習score percentile300件相当。これは最悪月が最も軽い頻度適合モデルであり、採用モデルではありません。

| month | trades | win_rate | expectancy_r | pf | maxdd_r | tp | sl | timeout |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 202502 | 218 | 0.49541 | -0.00100 | 0.99592 | 8.23547 | 25 | 25 | 168 |
| 202503 | 437 | 0.49428 | -0.00471 | 0.98161 | 11.87806 | 65 | 47 | 325 |
| 202504 | 377 | 0.51989 | 0.00059 | 1.00241 | 10.82393 | 32 | 54 | 291 |

直接net R回帰が比較的残り、TP先着確率を学習平均payoffでEVへ変換する方法は弱い結果でした。TIME決済の損益とSL gapがあるため、TP確率だけから2p−1でEVを計算していません。

## 4. 特徴量・interactionの読み方

診断Extra Treesの平均重要度上位は次のとおりです。これはモデル使用度であって「利益が出る条件」ではありません。

| feature | importance |
| --- | --- |
| m5_ema50_gap_pct64 | 0.00894 |
| m1_tick_volume_pct64 | 0.00830 |
| m1_ema5_gap_pct64 | 0.00800 |
| m15_atr14_price | 0.00755 |
| m1_rsi14_pct64 | 0.00749 |
| m5_rsi21_pct64 | 0.00678 |
| m15_atr14_pct64 | 0.00648 |
| shock_direction | 0.00643 |
| m1_bar_close_location | 0.00630 |
| m1_shock_x_ema20_50_gap_atr | 0.00620 |
| m15_tick_volume_pct64 | 0.00597 |
| m5_rsi14_pct64 | 0.00593 |

既存interactionの上位：

| feature | importance |
| --- | --- |
| m1_shock_x_ema20_50_gap_atr | 0.00620 |
| m15_shock_x_ema20_price_gap_atr | 0.00580 |
| m1_m5_rsi_x_trend | 0.00513 |
| m5_shock_x_range20_signed_efficiency | 0.00452 |
| m5_m15_alignment_product | 0.00449 |
| m1_shock_x_ema20_price_gap_atr | 0.00416 |
| m5_shock_x_rsi14_centered | 0.00330 |
| m5_m15_atr_ratio | 0.00310 |

Validation内・同じ通貨内でのpermutation、訓練期間の分位点で区切った翌月のfeature bin、PDP、interaction除外再学習、LightGBM TreeSHAPを実行しています。相関した特徴量の代替・不自然な組合せの影響があるため、個別指標の因果効果とは解釈しません。`interpretation_*.csv`と`diagnostic_*ranking.csv`を参照してください。

次は、訓練期間だけで決めた低位binと高位binを比較し、3評価月で差の符号が揃った状態です。direction=1はLONG、-1はSHORT。high_minus_lowは高位状態−低位状態の平均net R差。差がプラスでも両方の損益がマイナスの場合があり、売買ruleには採用していません。

| feature | direction | high_minus_low | low_ev | high_ev | min_bin_rows |
| --- | --- | --- | --- | --- | --- |
| m5_spread_atr | -1 | -0.12737 | -0.01305 | -0.14042 | 249 |
| m15_spread_atr | -1 | -0.11502 | -0.02845 | -0.14347 | 218 |
| m1_spread_atr | -1 | -0.11049 | -0.01425 | -0.12474 | 241 |
| m1_spread_atr | 1 | -0.10665 | -0.04079 | -0.14745 | 241 |
| m15_spread_atr | 1 | -0.10502 | -0.03132 | -0.13633 | 218 |
| m5_spread_atr | 1 | -0.09848 | -0.04338 | -0.14186 | 249 |
| m1_ema20_price_gap_atr | 1 | -0.05737 | -0.03046 | -0.08783 | 261 |
| m5_ema20_price_gap_atr | 1 | -0.05299 | -0.03382 | -0.08681 | 259 |
| m15_ema20_50_gap_atr | 1 | -0.03804 | -0.06208 | -0.10012 | 190 |
| m1_atr14_pct64 | 1 | -0.02383 | -0.06947 | -0.09330 | 275 |
| m15_ema20_price_gap_atr | 1 | -0.02367 | -0.04646 | -0.07013 | 282 |
| m15_ema_alignment | 1 | -0.02147 | -0.05457 | -0.07603 | 459 |
| m1_m15_alignment_product | 1 | -0.02086 | -0.05981 | -0.08067 | 205 |
| m1_m15_alignment_product | -1 | 0.02263 | -0.06710 | -0.04447 | 205 |
| m15_ema_alignment | -1 | 0.02400 | -0.07292 | -0.04891 | 459 |
| m15_ema20_price_gap_atr | -1 | 0.02488 | -0.06829 | -0.04341 | 282 |
| m1_macd_hist_atr | -1 | 0.03999 | -0.08985 | -0.04986 | 249 |
| m15_atr14_pct64 | 1 | 0.04393 | -0.09919 | -0.05526 | 172 |
| m15_ema20_50_gap_atr | -1 | 0.04581 | -0.07650 | -0.03069 | 190 |
| m5_atr14_pct64 | 1 | 0.05251 | -0.10777 | -0.05526 | 199 |
| m5_ema20_price_gap_atr | -1 | 0.05514 | -0.09390 | -0.03877 | 259 |
| m1_ema20_price_gap_atr | -1 | 0.05519 | -0.10634 | -0.05115 | 261 |
| m15_atr14_pct64 | -1 | 0.06547 | -0.08961 | -0.02414 | 172 |
| m1_rsi14_value | -1 | 0.06786 | -0.10741 | -0.03956 | 239 |

## 5. Frequency frontierとthreshold

100/200/300/500/800件相当を、固定EV・fit内percentile・fit内件数・過去calibration tail件数で比較しました。時系列の最後25%をcalibrationに残し、同じモデルを翌月まで固定。後から再fitしてscore尺度を変更していません。目標件数と成立件数は一致保証ではなく、全通貨1ポジション・拒否・episode密度で変わります。

`frequency_expectancy_frontier.csv`は全月の実際の件数とEV、`calibration_frequency_summary.csv`は全固定設定の分布です。月200件以上にすること自体はできましたが、それだけで正EVにはなりませんでした。

## 6. 通貨依存性

38の絶対単位featureを除いた448版も比較しましたが、normalized featureからも通貨は推測可能です。除外版が一律改善したわけではなく、モデル別の同一policy比較では悪化もあります。診断モデルではUSDJPYのプラスに対してUSDCHFの損失が大きく、通貨共通の安定edgeとは言えません。`diagnostic_symbol.csv`、`raw_scale_exclusion_paired.csv`を参照。

## 7. TP/SLとコストが残す問題

全評価期間の実行可能な両方向labelを集計したTIME比率（独立取引数ではない）：

| distance_atr | executed_rows | tp_first | sl_first | time_exit | time_exit_rate |
| --- | --- | --- | --- | --- | --- |
| 0.50000 | 16422 | 7101 | 9056 | 265 | 0.01614 |
| 0.75000 | 17740 | 7016 | 8724 | 2000 | 0.11274 |
| 1.00000 | 18156 | 5966 | 7285 | 4905 | 0.27016 |
| 1.50000 | 18302 | 3383 | 4234 | 10685 | 0.58382 |
| 2.00000 | 18394 | 1785 | 2276 | 14333 | 0.77922 |

診断2ATRモデルの追加コスト感度：

| extra_roundtrip_cost_pips | trades | expectancy_r | pf | total_r |
| --- | --- | --- | --- | --- |
| 0.00000 | 1032 | 0.01566 | 1.06519 | 16.16071 |
| 0.10000 | 1032 | 0.00683 | 1.02793 | 7.05240 |
| 0.20000 | 1032 | -0.00199 | 0.99201 | -2.05591 |
| 0.50000 | 1032 | -0.02847 | 0.89180 | -29.38083 |
| 1.00000 | 1032 | -0.07260 | 0.74732 | -74.92236 |

つまり、追加コストなし／0.1pipでは薄いプラス傾向が見えても、0.2pipで消える程度の余裕です。実Bid/Ask spreadはどの行にも含まれています。2ATRではTIMEが多く、「毎回RR1で勝敗が決まる戦略」でもありません。

## 8. QAと限界

| evidence | checks | pass_count | fail_count |
| --- | --- | --- | --- |
| qa_checks.csv | 74 | 74 | 0 |
| deterministic_rerun.csv | 792 | 792 | 0 |
| verify_source_integrity.csv | 3030 | 3030 | 0 |
| interpretation_qa.csv | 6 | 6 | 0 |
| interpretation_shap_additivity.csv | 6 | 6 | 0 |

人工18テストに加え、12固定構成を本当に再学習して予測・thresholdを比較しました。MQL source/EX5・既存fixture/expected・入力CSVのSHA不変を確認。元のJanuary/Aprilのlegacy-pool警告、February/Marchのgenerated fallbackは保持しています。15分決済は期限以降の最初の実quoteであり、厳密に900秒以内ではありません。bootstrap CIは候補選択の多重比較バイアスを補正しておらず、利益証明ではありません。

## 9. EA化可否と次の判断

**今回はEA化しません。** 今回分かったのは、取引数の維持は改善できても、方向・損益のsignalが追加コストと月別・通貨別変動を十分に上回っていないことです。同じデータでモデル数やthresholdを増やして救済せず、今回の全結果を保存します。5～6月の再評価を希望する場合も、この未達と観測済み期間である点を引き継ぐ必要があります。

主データ：`reports/analysis/tick_shock/technical_ml_discovery_20260911/`。設計：[事前仕様](technical_ml_discovery_preregistration.md)。詳細：[全体資料](technical_ml_discovery_results.md)。

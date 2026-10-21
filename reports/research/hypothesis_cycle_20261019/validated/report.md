# 応用ブレイクとRSI2押し目の固定研究サイクル

2026-10-19 JST。19条件、2024–2025年のみ。既存7条件の単一応用と新規12条件を全件評価した。

**追加の独立検証へ進める条件は0/19件**。SL先着・基準費用の完結口座でPF>1は6件。総損益と両年損益ゲートは2件、月次・取引頻度ゲートは0件、最初の3ゲート同時通過は0件。

## 実施した比較

- A：7条件のブレイク終値が既存境界を0.25ATR以上超える場合だけ採用。ドンチャン/ATRは前20本境界、雲は26本シフト済みの表示境界。
- B：6通貨H1×両方向。LONGは確定終値>EMA200かつRSI2が5以下から5超へ反転。SHORTは反対方向・95以上から95未満。次足以降の元の約定規則。
- TP=SL=1ATR、最大10実足。1条件1方向ごと独立USD10,000、目標risk0.1%/回、lot切下げ、同時1ポジション。
- 同足両到達はSL先着を主評価、TP先着を感度。費用ストレスは片道0.2→0.7pip、追加往復1pipを約定から再生。
- 期間・閾値・19条件・ゲートは結果を見る前に保存。成績を見て閾値や通貨を選び直していない。

## 主評価の全19条件

net_usdはspread/slippage/commission設定を含むが未知swapを含まない仮定損益。PFの分母は負け損益。CIは取引Rの暦4週ブロック再標本化5,000回。未完結口座のPF/PnLは観測済み決済だけの参考値。

| cell_id | complete | n_trades | pf | net_usd | stress_net_usd | equity_positive_months | data_months | equity_longest_negative_months | median_monthly_entries | mean_r_ci_low | mean_r_ci_high | holm_p |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| USDJPY_donchian_LONG_margin025 | True | 304 | 1.081 | 105.576 | -52.006 | 14 | 24 | 3 | 12.000 | -0.050 | 0.142 | 1.000 |
| USDJPY_donchian_SHORT_margin025 | True | 250 | 0.983 | -19.069 | -90.051 | 12 | 24 | 2 | 10.000 | -0.157 | 0.104 | 1.000 |
| USDJPY_atr_breakout_LONG_margin025 | True | 89 | 1.081 | 32.022 | -51.703 | 11 | 24 | 5 | 3.500 | -0.127 | 0.236 | 1.000 |
| USDJPY_atr_breakout_SHORT_margin025 | True | 48 | 1.295 | 56.524 | 42.519 | 13 | 24 | 4 | 1.000 | -0.150 | 0.364 | 1.000 |
| USDCHF_donchian_SHORT_margin025 | True | 145 | 1.194 | 116.072 | 46.203 | 6 | 17 | 5 | 8.000 | -0.082 | 0.270 | 1.000 |
| USDCHF_atr_breakout_SHORT_margin025 | True | 26 | 0.798 | -26.488 | -34.734 | 4 | 17 | 3 | 1.000 | -0.401 | 0.243 | 1.000 |
| AUDUSD_ichimoku_cloud_SHORT_margin025 | True | 179 | 1.012 | 9.690 | -184.550 | 13 | 24 | 4 | 7.000 | -0.133 | 0.149 | 1.000 |
| USDJPY_rsi2_pullback_LONG_rsi2 | True | 174 | 0.845 | -130.383 | -201.570 | 7 | 24 | 5 | 7.500 | -0.231 | 0.073 | 1.000 |
| USDJPY_rsi2_pullback_SHORT_rsi2 | True | 119 | 0.812 | -106.907 | -149.385 | 7 | 24 | 3 | 4.500 | -0.283 | 0.051 | 1.000 |
| EURUSD_rsi2_pullback_LONG_rsi2 | True | 159 | 0.790 | -167.190 | -300.270 | 8 | 24 | 5 | 7.000 | -0.292 | 0.050 | 1.000 |
| EURUSD_rsi2_pullback_SHORT_rsi2 | True | 141 | 0.629 | -284.140 | -421.950 | 6 | 24 | 3 | 6.000 | -0.369 | -0.079 | 1.000 |
| GBPUSD_rsi2_pullback_LONG_rsi2 | True | 153 | 0.673 | -259.640 | -329.840 | 9 | 24 | 3 | 6.000 | -0.359 | -0.016 | 1.000 |
| GBPUSD_rsi2_pullback_SHORT_rsi2 | True | 129 | 0.548 | -330.550 | -375.760 | 6 | 24 | 8 | 4.500 | -0.431 | -0.137 | 1.000 |
| AUDUSD_rsi2_pullback_LONG_rsi2 | True | 140 | 0.760 | -170.310 | -250.560 | 6 | 24 | 7 | 5.500 | -0.314 | 0.044 | 1.000 |
| AUDUSD_rsi2_pullback_SHORT_rsi2 | True | 159 | 1.056 | 40.670 | -113.740 | 10 | 24 | 5 | 6.500 | -0.112 | 0.179 | 1.000 |
| USDCHF_rsi2_pullback_LONG_rsi2 | True | 89 | 0.530 | -245.793 | -289.311 | 4 | 17 | 7 | 5.000 | -0.427 | -0.172 | 1.000 |
| USDCHF_rsi2_pullback_SHORT_rsi2 | True | 106 | 0.869 | -67.192 | -174.965 | 6 | 17 | 4 | 7.000 | -0.257 | 0.137 | 1.000 |
| USDCAD_rsi2_pullback_LONG_rsi2 | True | 146 | 0.690 | -245.046 | -364.423 | 5 | 24 | 6 | 5.500 | -0.349 | -0.024 | 1.000 |
| USDCAD_rsi2_pullback_SHORT_rsi2 | True | 122 | 0.497 | -363.930 | -443.636 | 6 | 24 | 4 | 5.000 | -0.469 | -0.161 | 1.000 |

## 既存ブレイク応用の変化

原候補を保持し、除外後に新たに入る取引も口座再生する。下表の見送った勝ち/負けは旧台帳との差分であり、単純削除の損益を実行結果と混同しない。原候補当たりR差の区間は同じ週を再標本化する。

| cell_id | original_complete | variant_complete | original_trades | variant_trades | removed_winners | removed_losers | new_trades | original_cash_usd | variant_cash_usd | cash_difference_usd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| USDJPY_donchian_LONG_margin025 | True | True | 478 | 304 | 81 | 102 | 9 | -125.717 | 105.576 | 231.293 |
| USDJPY_donchian_SHORT_margin025 | True | True | 385 | 250 | 62 | 75 | 2 | -128.969 | -19.069 | 109.900 |
| USDJPY_atr_breakout_LONG_margin025 | True | True | 137 | 89 | 25 | 25 | 2 | 13.656 | 32.022 | 18.366 |
| USDJPY_atr_breakout_SHORT_margin025 | True | True | 65 | 48 | 7 | 10 | 0 | 25.983 | 56.524 | 30.540 |
| USDCHF_donchian_SHORT_margin025 | True | True | 271 | 145 | 56 | 72 | 2 | -14.963 | 116.072 | 131.036 |
| USDCHF_atr_breakout_SHORT_margin025 | True | True | 38 | 26 | 7 | 5 | 0 | -6.146 | -26.488 | -20.342 |
| AUDUSD_ichimoku_cloud_SHORT_margin025 | True | True | 289 | 179 | 55 | 64 | 9 | -82.400 | 9.690 | 92.090 |

| cell_id | paired_r_per_original | paired_ci_low | paired_ci_high |
| --- | --- | --- | --- |
| USDJPY_donchian_LONG_margin025 | 0.047 | 0.005 | 0.090 |
| USDJPY_donchian_SHORT_margin025 | 0.027 | -0.026 | 0.087 |
| USDJPY_atr_breakout_LONG_margin025 | 0.009 | -0.079 | 0.100 |
| USDJPY_atr_breakout_SHORT_margin025 | 0.046 | -0.050 | 0.155 |
| USDCHF_donchian_SHORT_margin025 | 0.055 | -0.036 | 0.144 |
| USDCHF_atr_breakout_SHORT_margin025 | -0.056 | -0.172 | 0.070 |
| AUDUSD_ichimoku_cloud_SHORT_margin025 | 0.029 | -0.043 | 0.098 |

## 月次と停止判定

月次損益は月末含み損益込み。無取引月も分母に残す。USDCHFの未取得2024年1〜7月はNA。利用可能月の2/3以上黒字、連続赤字3月以下、活動月80%以上、月別新規約定中央値5件以上を先に固定した。毎月の黒字を保証する基準ではなく、今回の研究継続目標である。年/月別再現性は独立OOSではない。

| cell_id | net_2024_usd | net_2025_usd | gate_profit | gate_monthly | gate_stress | gate_statistics | control_status | failure_reasons |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| USDJPY_donchian_LONG_margin025 | 49.063 | 56.513 | True | False | False | False | not_run_failed_gates_1_to_3 | monthly_or_frequency;cost_stress;uncertainty |
| USDJPY_donchian_SHORT_margin025 | -95.586 | 76.517 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDJPY_atr_breakout_LONG_margin025 | -17.724 | 49.746 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDJPY_atr_breakout_SHORT_margin025 | 26.811 | 29.713 | True | False | True | False | not_run_failed_gates_1_to_3 | monthly_or_frequency;uncertainty |
| USDCHF_donchian_SHORT_margin025 | -43.671 | 159.744 | False | False | True | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;uncertainty |
| USDCHF_atr_breakout_SHORT_margin025 | -28.271 | 1.783 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| AUDUSD_ichimoku_cloud_SHORT_margin025 | 55.380 | -45.690 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDJPY_rsi2_pullback_LONG_rsi2 | -110.912 | -19.471 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDJPY_rsi2_pullback_SHORT_rsi2 | -7.949 | -98.958 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| EURUSD_rsi2_pullback_LONG_rsi2 | -80.720 | -86.470 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| EURUSD_rsi2_pullback_SHORT_rsi2 | -157.910 | -126.230 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| GBPUSD_rsi2_pullback_LONG_rsi2 | -123.610 | -136.030 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| GBPUSD_rsi2_pullback_SHORT_rsi2 | -139.460 | -191.090 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| AUDUSD_rsi2_pullback_LONG_rsi2 | -115.120 | -55.190 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| AUDUSD_rsi2_pullback_SHORT_rsi2 | 53.000 | -12.330 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDCHF_rsi2_pullback_LONG_rsi2 | -107.537 | -138.255 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDCHF_rsi2_pullback_SHORT_rsi2 | -45.853 | -21.339 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDCAD_rsi2_pullback_LONG_rsi2 | -141.350 | -103.696 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |
| USDCAD_rsi2_pullback_SHORT_rsi2 | -89.828 | -274.102 | False | False | False | False | not_run_failed_gates_1_to_3 | profit_or_year;monthly_or_frequency;cost_stress;uncertainty |

## カレンダー・候補母集団・未完了の扱い

全主比較にsource暦12月24日〜1月2日の新規エントリー休止を適用。確定シグナル日、および実際の入口で観測できる約定日を検査する。未来の価格や欠損を検査して候補を選ばない。これは旧候補への共通の新運用条件であり、従来結果の完全再現ではない。実際の取引所/ブローカー祝日検証でもない。

新19条件×2順序のうち休止あり基準費用は38/38口座が完結。休止なし対照は36/38口座が完結。未知欠損を跨いで未決済になる場合、強制的に平らとみなして再開しない。打切り後の月次値は作らない。

追加ランダム対照は最初の3ゲート通過条件のみ実行する事前規則。今回は対象0条件、保存行0件。対象0なら実装の途中停止ではなく、固定した打切り判定である。対照は月と方向を共通にし、条件付き対照だけhour/weekday/volも一致させる。実行数は候補数と別である。

## 解釈の限界と次の判断

既存PF>1から選んだA、およびその過去診断に基づく仮説自体に選択偏りがある。19件のHolm補正は過去の探索全体を補正しない。4週ブロックCIは依存性への近似で、強い非定常性を解決しない。合計Rや各独立口座の損益を単純合算して運用ポートフォリオとはしない。

実口座手数料・swap・歴史的lot仕様・source時計・marginは未検証。Bid OHLCとbar spreadからの代理約定であり、MT5実tickテストでも独立期間評価でもない。全費用控除後の実運用期待値が正と結論しない。

今回の固定目標を満たす条件がないため、2案の追加調整はここで保留する。月次赤字を見て毎月ルールを変更せず、次に進むなら別の市場仮説を少数固定し、未閲覧の将来期間を確保する。

## 成果物

- [対話型ダッシュボード](dashboard.html)
- [全条件CSV](verdict.csv) / [月次CSV](monthly.csv) / [年次CSV](yearly.csv)
- [元候補処理CSV](original_dispositions.csv) / [応用比較CSV](paired_comparison.csv)
- [口座シナリオCSV](accounts.csv) / [ランダム対照CSV](random_controls.csv)
- 同名Parquet、research.duckdb、accounts/の約定・イベント・equity台帳、candidates/の全候補。
- manifest.jsonに入力/凍結実装/新実装SHA、Git版、依存版、seed、費用、holdout不使用を保存。

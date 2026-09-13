# USDJPY専用 Tick-Shock ML：結果と再現手順

## 結論

**USDJPY専用化だけでは、月200取引を維持する安定した正の期待値は確認できなかった。**
採用候補ではなく、事前指定どおり1つのholdout検証用候補を凍結した。5月は小幅プラス、6月はマイナスで、2か月合計もマイナス。結果を見てモデル・threshold・TP/SLを変更していない。
`STABLE_POSITIVE_EDGE_NOT_ESTABLISHED` / `FREQUENCY_TARGET_NOT_MET_IN_HOLDOUT` / `PRODUCTION_NOT_ELIGIBLE`。
5～6月は過去研究で観測済みの期間。今回のUSDJPY-only研究で未使用のholdoutであり、完全未使用OOSとは呼ばない。

## 1. 母数と取引頻度

以下は1 ATR geometry。shock数は残存episode archiveに含まれるanchor＋repeatの数であり、全statistical detectorの未集約検知総数と同一とは主張しない。`statistical_candidates`はpersistence判定前候補として別列に保存している。全raw検知の通貨別独立再集計には、保存されていないdetector event全行が必要。episode数とMLラベル数は実CSVの正確な件数。
|month|shock_detections_in_episode_archive|episodes|executable_long|executable_short|
|---|---|---|---|---|
|202501|4379|656|633|633|
|202502|8385|959|930|930|
|202503|11469|1126|1107|1107|
|202504|11327|903|865|865|
|202505|6809|840|815|815|
|202506|3237|476|447|447|

USDJPYだけでも各月200件以上の売買可能episodeがあり、母数不足が主因ではない。LONG/SHORTは同じepisodeの相反する2ラベルであり独立サンプルを2倍に数えない。

## 2. 固定した研究設計

- 1月→2月、1～2月→3月、1～3月→4月のexpanding walk-forward。翌月へまたがるラベル・clusterを除外。
- 486 causal features／raw-unit38列除外448版。新規特徴量なし。6モデル×2版×5 geometry=60モデル設定、180fold、12policy、720比較セル。
- RR1、TP=SL=0.5/0.75/1/1.5/2 ATR、M5 ATR14、900秒後の最初の利用可能quoteによる時間決済。
- LONG/SHORTのNET_Rを別々に推定し、高い方がcutoff以上なら選択。tieはNO TRADE。注文不可と判明してから反対側を選び直さない。
- cutoffは学習score percentileまたは学習期間のportfolio件数だけで算出。将来月を見て件数を合わせない。各月の目標は保証されない。
- spreadは実Bid/Ask経路に内包。Python primaryはさらに往復0.2pipを控除する仮定。実commissionの観測値ではない。0.4pipはprimaryからさらに0.2pip悪化するstress。
- 1 pending/open position、全データ処理の最初にUSDJPYを抽出。他通貨をこのモデルの学習・threshold・損益に使わない。

## 3. モデル比較（開発forwardのみ）

各familyについて月200件を優先し、最悪月のEVから順に事前ルールで選んだ代表。LOGISTICというコード名はNET_RではRidge回帰を指す。最高単月損益順ではない。
|family|variant|geometry|policy|trades|min_month_trades|expectancy_r|pf|worst_month_ev|
|---|---|---|---|---|---|---|---|---|
|ELASTICNET|FULL486|5|FREQUENCY_150|880|252|-0.01969|0.91780|-0.02832|
|EXTRA_TREES|SCALE_FREE|4|PERCENTILE_300|1077|303|-0.01625|0.94796|-0.03651|
|LIGHTGBM|SCALE_FREE|5|ALL|2917|872|-0.05235|0.80065|-0.06280|
|LOGISTIC|SCALE_FREE|5|FREQUENCY_200|995|288|-0.03849|0.84645|-0.04669|
|RANDOM_FOREST|FULL486|2|PERCENTILE_200|939|207|-0.03154|0.93405|-0.04597|
|SHALLOW_TREE|SCALE_FREE|4|FREQUENCY_300|1276|322|-0.04020|0.87881|-0.05101|

全720セルのうちpooled EVがプラスは56セル。ただし全forward月200件以上かつプラスは0セル。頻度を含む採用基準通過は0。少数tradeの高EVを今回の成功として採用しない。

## 4. 凍結候補と月別成績

**ELASTICNET / FULL486 / NET_R / TP=SL=2.0 ATR**。policyは`FREQUENCY_150`。最終thresholdは **0.020541055203914662R**。
名称の150は学習期間calibration目標であり、実際のforward件数ではない。開発では252～365件/月となったが、holdoutでは96/44件まで減った。1～4月全体の利用可能ラベルで最終fitし、そのfitのscoreから同じ手順でthresholdを凍結した。
|scope|month|trades|win_rate|expectancy_r|pf|maxdd_r|total_r|
|---|---|---|---|---|---|---|---|
|DEVELOPMENT|202502|365|0.50411|-0.01900|0.92378|11.83672|-6.93665|
|DEVELOPMENT|202503|252|0.46825|-0.01166|0.94690|11.00504|-2.93870|
|DEVELOPMENT|202504|263|0.47148|-0.02832|0.88432|12.52389|-7.44760|
|DEVELOPMENT|ALL|880|0.48409|-0.01969|0.91780|22.39318|-17.32296|
|HOLDOUT|202505|96|0.47917|0.01840|1.07989|6.45999|1.76636|
|HOLDOUT|202506|44|0.45455|-0.11855|0.64597|8.76615|-5.21636|
|HOLDOUT|ALL|140|0.47143|-0.02464|0.90636|15.22614|-3.45000|

DDは固定1Rの確定損益曲線。EAの浮動損益込みequity DDや口座リスク%とは異なる。

## 5. Frequency–expectancy frontier

目標100/150/200/300件ごとに、両calibration方式・事前モデルgridのforward安定性で代表を保存。全720セルは`candidate_frontier.csv`、全foldは`walk_forward.csv`。
|target_frequency|policy|geometry|trades|min_month_trades|expectancy_r|worst_month_ev|
|---|---|---|---|---|---|---|
|100|PERCENTILE_100|5|643|154|0.00525|-0.00286|
|150|FREQUENCY_150|5|880|252|-0.01969|-0.02832|
|200|FREQUENCY_200|5|1098|324|-0.02501|-0.03507|
|300|PERCENTILE_300|5|1534|479|-0.03040|-0.03214|

高scoreだから翌月でも同じ頻度・損益になるとは言えない。最終score分布はMay/Juneで低下し、学習calibrationのfrequencyが維持されなかった。`score_distributions.csv`と`holdout_monthly.csv`に分布を保存。

## 6. 技術状態・interactionの解釈

重要度上位はモデル内で使われた程度であって、利益の証明ではない。以下は選択されたElasticNetの3forward fitを集約した標準化係数の絶対値。
|feature|normalized|
|---|---|
|m1_realized_vol60_atr|0.06372|
|m1_m15_atr_ratio|0.06166|
|m15_rsi7_slope3|0.03533|
|m1_realized_vol20_atr|0.03514|
|m1_range5_width_atr|0.03273|
|m5_ema_alignment|0.03003|
|m5_ema5_sma_gap_atr|0.02994|
|m5_upper_wick_atr|0.02684|
|m5_shock_x_macd_hist_atr|0.02509|
|m15_realized_vol60|0.02341|
|m1_realized_vol5|0.02220|
|m1_m5_atr_ratio|0.02184|

相対的に重要なinteraction：
|feature|normalized|
|---|---|
|m1_m15_atr_ratio|0.06166|
|m5_shock_x_macd_hist_atr|0.02509|
|m1_m5_atr_ratio|0.02184|
|m5_m15_macd_hist_product|0.02166|
|m1_body_x_tick_activity|0.01779|
|m15_rsi14_x_adx14|0.01513|
|m15_body_x_tick_activity|0.01084|
|m1_ema20_gap_x_rsi14|0.00936|

M1 realized volatility、M1/M15 ATR比、M15 RSI slope、M5 EMA整列、EMA/SMA差、shock×MACDが主に使われた。EMA距離・RSI percentile・MACD・ATR percentile・spread/ATR・activity・cross-TF状態の学習quintile別LONG/SHORT損益は`feature_bins.csv`に記録した。全行の片方向ラベル診断であり、そのbinを新規売買ルールとして採用していない。
特徴量groupをvalidation月内でシャッフルした際の変化（正のdegradationは、その情報を壊すと損益が悪化したことを示す）：
|feature_or_group|total_r_degradation|ev_rmse_increase|
|---|---|---|
|INTERACTIONS|8.20466|0.00547|
|LIQUIDITY|-1.79123|0.00249|
|MOMENTUM|4.00717|0.00063|
|STRUCTURE|4.80872|0.00212|
|TREND|0.70262|0.00405|
|VOLATILITY|5.52489|0.00488|

主要technical状態の低い学習quintileと高いquintileのforward EV（LONG/SHORT独立ラベル、モデル選択portfolioではない）：
|feature|direction|low_bin_n|low_bin_ev|high_bin_n|high_bin_ev|
|---|---|---|---|---|---|
|m5_ema20_price_gap_atr|LONG|497|-0.01085|621|-0.07126|
|m5_ema20_price_gap_atr|SHORT|497|-0.06997|621|-0.01314|
|m5_ema20_50_gap_atr|LONG|648|-0.04347|688|-0.05383|
|m5_ema20_50_gap_atr|SHORT|648|-0.03377|688|-0.04281|
|m5_rsi14_pct64|LONG|513|-0.00384|640|-0.05080|
|m5_rsi14_pct64|SHORT|513|-0.07992|640|-0.03845|
|m5_macd_hist_atr|LONG|550|-0.03125|624|-0.06216|
|m5_macd_hist_atr|SHORT|550|-0.04960|624|-0.02215|
|m5_atr14_pct64|LONG|518|-0.06556|559|-0.05787|
|m5_atr14_pct64|SHORT|518|-0.06897|559|-0.00358|
|m5_spread_atr|LONG|685|-0.01802|340|-0.11260|
|m5_spread_atr|SHORT|685|-0.03396|340|-0.09449|
|m1_tick_volume_pct64|LONG|616|-0.01597|576|-0.04893|
|m1_tick_volume_pct64|SHORT|616|-0.05614|576|-0.05763|
|m5_ema_alignment|LONG|1009|-0.04987|872|-0.06289|
|m5_ema_alignment|SHORT|1009|-0.03565|872|-0.02315|
|m1_m5_alignment_product|LONG|53|-0.15379|1109|-0.04596|
|m1_m5_alignment_product|SHORT|53|0.05669|1109|-0.04025|
|m1_m15_alignment_product|LONG|381|-0.03501|766|-0.06262|
|m1_m15_alignment_product|SHORT|381|-0.04552|766|-0.02686|

読み方：M5の価格−EMA20距離が低い側ではLONG、高い側ではSHORTの損失が相対的に小さい。RSI/MACDにも似た相対的な逆張り傾向があるが、上記の両端binの多くは依然マイナス。spread/ATRが高い状態は両方向とも悪化する。低spreadは損失を減らすが、それだけで正EVにはならない。高ATR側のSHORTはゼロに近づくものの、採用できる利益の証明ではない。M1/M5整列の一部小binにプラスがあっても53件などの小標本で、月200件の戦略へ置き換えない。

係数・permutationは相関特徴量の影響を受ける。LightGBMのTreeSHAPは同じgeometry/feature版で別途行った説明用モデルであり、凍結ElasticNetのSHAPと混同しない。SHAPの加法一致を検証済み。`partial_dependence.csv`も予測応答の診断で、現実に存在しない特徴量組合せを含み得る。

## 7. TP/SL・コスト・時間決済

2 ATRが選ばれたのは短期TP勝率が優れたからではなく、頻度を維持した比較で最悪月の損失が相対的に小さかったため。採用候補ではない。開発83.5%、holdout77.9%がTIMEとなり、短期first-touch戦略としては幅が大きい。
|geometry|direction|trades|timeout_rate|distance_spread_median|mfe_900_atr_median|mae_900_atr_median|
|---|---|---|---|---|---|---|
|1.00000|-1.00000|3492.00000|0.01833|10.18333|0.70439|0.78087|
|1.00000|1.00000|3492.00000|0.01861|10.18333|0.67941|0.80549|
|2.00000|-1.00000|3526.00000|0.12167|15.00000|0.70534|0.78343|
|2.00000|1.00000|3526.00000|0.12167|15.00000|0.67625|0.80939|
|3.00000|-1.00000|3535.00000|0.28741|20.00000|0.70554|0.78487|
|3.00000|1.00000|3535.00000|0.29618|20.00000|0.67952|0.81130|
|4.00000|-1.00000|3544.00000|0.62161|29.91667|0.70439|0.78683|
|4.00000|1.00000|3544.00000|0.61795|29.91667|0.67973|0.81175|
|5.00000|-1.00000|3552.00000|0.80856|39.69048|0.70404|0.78710|
|5.00000|1.00000|3552.00000|0.80828|39.69048|0.67814|0.81224|

|scope|cost_pips|expectancy_r|pf|total_r|
|---|---|---|---|---|
|DEVELOPMENT|0.00000|-0.00926|0.96047|-8.14691|
|DEVELOPMENT|0.10000|-0.01447|0.93889|-12.73493|
|DEVELOPMENT|0.20000|-0.01969|0.91780|-17.32296|
|DEVELOPMENT|0.40000|-0.03011|0.87701|-26.49900|
|DEVELOPMENT|0.50000|-0.03533|0.85729|-31.08703|
|DEVELOPMENT|1.00000|-0.06139|0.76517|-54.02715|
|HOLDOUT|0.00000|-0.01455|0.94354|-2.03753|
|HOLDOUT|0.10000|-0.01960|0.92475|-2.74377|
|HOLDOUT|0.20000|-0.02464|0.90636|-3.45000|
|HOLDOUT|0.40000|-0.03473|0.87070|-4.86248|
|HOLDOUT|0.50000|-0.03978|0.85343|-5.56872|
|HOLDOUT|1.00000|-0.06500|0.77214|-9.09991|

top5利益除外後、開発は約−22.30R、holdoutは約−8.41R。採用条件を満たさない。cluster/day bootstrap CIは`bootstrap.csv`参照。CIは開発でのモデル選択バイアスを補正していない。
時間決済は既存ラベル生成器の「900秒以降の最初のquote」であり、厳密な15分以内を保証しない。休場・quote間隔・global replay遅延による長い保有を改変せず保存した。
|scope|hold_over_900|hold_over_905|max_hold_seconds|
|---|---|---|---|
|DEVELOPMENT|731|19|173492.59500|
|HOLDOUT|108|10|1515.88600|

900秒超の観測を消したり、過去quoteへ時間決済を戻して損益を改善したりしていない。

## 8. 6通貨共通モデルとの比較

前回の共通モデルでUSDJPYだけを取り出し、他通貨とのposition競合を除いて既存予測を再集計した参考比較：
|month|trades|expectancy_r|pf|maxdd_r|
|---|---|---|---|---|
|202502|154|-0.00286|0.98742|5.96702|
|202503|159|0.06067|1.29963|5.60736|
|202504|109|0.00124|1.00541|11.31476|

共通モデルはExtraTrees / SCALE_FREE / 2 ATRで主にSHORT、今回はElasticNet / FULL486 / 2 ATRで開発LONGが多い。共通モデルのreferenceは月109～159件と頻度が低い。今回の専用モデルは開発252～365件だが全月マイナスだった。
重要な比較制限：前回は学習prefix75%＋校正tail、今回は指定の全prefix expanding fitであり、選択familyやfrequencyも異なる。したがってこの差を「USDJPY専用化だけの因果効果」とは断定しない。他5通貨を再学習に使用する追加実験は行っていない。前回共通モデルは今回の5～6月へ新たに適用していないため、holdoutの公平なcommon対USDJPY比較は未実施。

## 9. データ品質・QA

- Jan/Aprは旧research pool警告を保持したscoped Technical collection PASS_WITH_LEGACY_WARNING。全pipeline validatedとはしていない。
- Marchのtester journalにはUSDJPYのgenerated/discarded tick fallbackの警告がある。モデル4指定だけで100%real-tickを保証しない。過去証跡のUSDJPY 1,431 symbol-minutesは参照値で、各episodeの完全なtick由来追跡はできない。
- 元のfixture/expected、detector、既存feature producerは変更なし。新しいPython unit13件と再利用core unit18件がPASS。最初の追加unitのfixture列衝突1件を直した経緯は初回logとfinal logを両方保存。研究計算・expected損益を変えていない。
- 独立損益計算、独立portfolio選択、causal clocks、selected/final model deterministic refit、全fitのpurge、既存source SHAを検証。`qa_checks.csv`の件数にはsource SHAなどの検査を含むため、独立した売買サンプル数と混同しない。
- 重み/thresholdはfreeze JSON/PKL/SHAで封印。holdout commandは既存開封記録がある場合に再評価を拒否する。監査・再集計は既存結果を読むだけ。

## 10. MT5実約定

全2,160 forward policyの独立再集計: 17,280 checks / 0 failures。圧縮USDJPY入力から全180 fitを再実行: 17,820 checks / 0 failures。これらは再現性検査数であり独立取引数ではない。

|month|trades|net_profit|expectancy_r|pf_money|maxdd_money|commission|fee|swap|
|---|---|---|---|---|---|---|---|---|
|202505.00000|95.00000|22.62000|0.02744|1.11385|60.46000|0.00000|0.00000|0.00000|
|202506.00000|44.00000|-48.47000|-0.11752|0.64014|77.22000|0.00000|0.00000|0.00000|

MT5 QA failures: 0。全期間集約：`{"commission": 0.0, "expectancy_r": -0.018444722211396945, "fee": 0.0, "hold_over_900": 108, "long": 32, "max_hold": 909.42, "maxdd_money": 137.68, "maxdd_r": 14.82352821488897, "net_profit": -25.85, "pf_money": 0.9224608554802328, "pf_r": 0.9285761637284339, "short": 107, "sl": 17, "swap": 0.0, "time": 108, "tp": 14, "trades": 139, "win_rate": 0.48201438848920863}`。
Python labelと現在quoteでの成行注文は完全に同じ約定価格にはならない。シグナル/feature parityとtrade identity差・fill差・exit差を分離して`trade_comparison.csv`へ保存した。actual costがゼロでも未観測とは混同せず、当該testerのdealで観測したゼロに限定する。

検証専用EA：`mql/Experts/ExpectedValue_USDJPY_TickShockMLHoldout.mq5`。通常チャート/実口座/デモ口座では初期化を拒否する。研究EA本体へ注文機能を追加せず、新wrapperだけを使用。既存6通貨dispatcherは収集時刻を保つため維持し、USDJPY以外のsnapshotを注文/モデル評価前に拒否する。
MetaEditor0 errors/0 warnings、学習3,644件のMQL推論parity PASS、学習日production wiring smoke PASS。最初のparity完了時、terminal shutdown待ちのためrunnerが安全停止した。モデル・EX5・設定SHA一致を確認した明示resumeのみ実施し、月次runの上書き/再試行はしていない。

## 再現と成果物

- `docs/research/tick_shock/usdjpy_only_ml_preregistration.md`：事前固定。
- `reports/analysis/tick_shock/usdjpy_only_ml_20260912/`：全分析、freeze、QA、元USDJPYのみの圧縮入力。
- `reports/backtest/batches/usdjpy_only_ml_20260912/`：parity/smoke/May/June、コンパイルと実約定。
- `tools/tick_shock/usdjpy_only_ml.py`：development → sealed holdout。
- `audit_usdjpy_only_ml.py`：interpret / summarize --holdout。
- `prepare_usdjpy_only_mt5.py` / `run_usdjpy_only_mt5.ps1` / `reconcile_usdjpy_only_mt5.py`：MT5経路。
- `test_usdjpy_only_ml.py` / `package_usdjpy_only_evidence.py`：回帰テスト・データ搬送。
- `reproduce_usdjpy_only_evidence.py`：圧縮USDJPY入力から同じ選択/重みの監査。

既存runへdevelopmentやholdoutを上書き実行しない。再集計は次を使用：
```powershell
python tools/tick_shock/test_usdjpy_only_ml.py
python tools/tick_shock/audit_usdjpy_only_ml.py summarize --holdout
python tools/tick_shock/reconcile_usdjpy_only_mt5.py
```

## 次の判断

本候補を実資金へ投入しない。USDJPY単独の母数はあるが、事前情報から高頻度かつコスト後プラスの選択を安定して作れていない。May/Juneを再調整に流用しない。今後の別研究では、score校正の月間変動と実行時計/休場時間の影響を先に分離し、追加探索をするなら新しい事前仕様と検証期間を用意する。

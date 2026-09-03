# Step 15K: tradeable move / clean excursion / cross-symbol ATR normalization

## 結論

2025年3月の反復利用済み開発データには、ATR正規化した目標へ限定MAE内で到達する `TRADEABLE_MOVE_POPULATION_EXISTS`。また、Step 15Iで固定したhigh-movement条件は、基準幾何 `TP=0.40 ATR / hold=900s / MAE<=0.25 ATR` でclean move率を20.54%（38/185、183 clusters、cluster bootstrap 95% CI 15.14%–26.35%）まで高め、unselectedの4.82%（77/1,598、1,522 clusters、95% CI 3.83%–5.85%）を上回った。45セルすべてで差は正だった。

ただし、clean moveの大半はUSDJPYに集中し、AUDUSD/USDCHFでは基準セルのclean moveが0、GBPUSDはgenerated-tick fallbackの区間対応が得られず全417 episodeを正式推論から除外した。これは利益、方向予測、実SL、またはOOS edgeの証拠ではない。正式判定は `HIGH_MOVEMENT_FILTER_SUPPORTS_CLEAN_MOVE_IN_DEVELOPMENT_SAMPLE`、`CLEAN_MOVE_SIGNAL_NOT_ESTABLISHED`、`DIRECTIONAL_EDGE_NOT_ESTABLISHED`、`CROSS_SYMBOL_ROBUSTNESS_NOT_ESTABLISHED`、`PARAMETER_FREEZE_NOT_READY`、`OOS_VALIDATION_REQUIRED`、`PRODUCTION_NOT_ELIGIBLE` とする。

## 実行条件と証跡

- run: `reports/backtest/runs/20260903_ts15k_tradeable_move_r1_202503/`
- 期間: 2025-03-01から2025-04-01、EURUSD M1 driver、6 symbols、real ticks、`REALIZABLE_EA`
- source commit: `54b9abca11a5ba5a6d2271bcfa0854217f897bf6`
- source SHA-256: `D04DE6F9465C64A59BE435FE666069BA1C3FF056D71C0AB104FC43B558C315AC`
- EX5 SHA-256: `528B3F7D5A54675591289898492B45425F1A10B4F8CF987BD7824381FC48BFD8`
- runtime: 708.358秒、10,587,807 tester ticks、最大tester memory 502 MB
- 注文・trade: 0。研究EAの無注文設計を維持した。

## Population funnel

| stage | count | interpretation |
|---|---:|---|
| raw candidates | 74,415 | detector前段の候補総数 |
| detector event rows | 21,799 | Step 15K detector feature rows |
| persistent episodes | 3,151 | Step 15Jと同一identity |
| valid causal t0 | 3,151 | confirmation後の同一通貨実quote |
| complete lag-valid 60m path | 3,103 | 46 lag censor、2 end-of-data censorを除外 |
| analysis ready | 2,696 | complete path、ATR有効、GBPUSD除外 |
| relative-state ready | 1,783 | 各featureに同一通貨・過去100件以上 |
| high movement selected | 185 | frozen q30/q70/q70条件 |

High-movement NOT_READYは理由とhistory countをepisode単位で保存した。主因は最初の100件の履歴不足と、離散的なtick-activityが0になるepisodeである。GBPUSDは別理由 `EXCLUDED_TICK_QUALITY` とした。

## Clean-move geometry

主要45セルはTP 0.30/0.40/0.50 ATR、hold 600/900/1,800秒、pre-TP MAE上限 0.15/0.20/0.25/0.30/0.40 ATRの直積で、セル選択や最適化を行っていない。基準表示セル（選抜セルではない）の内訳は次の通り。

| TP | hold | MAE limit | RR feasibility | eligible | continuation | reversal | both | noisy | insufficient |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.40 ATR | 900s | 0.25 ATR | 1.60 | 2,696 | 84 | 104 | 0 | 2,473 | 35 |

RR feasibilityは `TP_ATR / MAE_LIMIT_ATR` であり、実際のstop提案ではない。RR>=1.0は42セル、>=1.2は36、>=1.5は24、>=2.0は18。RR>=1.2のclean rate範囲は1.15%–19.14%だった。clean率だけでセルを選ばない。

## Holding time

基準 `TP=0.40 / MAE=0.25` ではclean件数が300秒174、600秒187、900秒188、1,800秒188、3,600秒188だった。追加利益は600–900秒でほぼ飽和し、`HOLDING_LIMIT_CANDIDATE_FOUND` は10–15分とする。ただしOOSで固定していない。

## Cross-symbol / session

基準セルのeither-clean率はAUDUSD 0%、EURUSD 8.87%、USDCAD 1.58%、USDCHF 0%、USDJPY 15.51%。high-movement clean 38件のうち34件がUSDJPYであり、cross-symbol robustnessは成立していない。session別はLONDON 4.27%、NEW_YORK 9.70%、OTHER 12.04%、OVERLAP 8.26%、TOKYO 4.83%で、すべて記述統計に限定する。

## Relative-state features

past-only ATR percentileはQ1からQ4へclean率が2.27%、4.80%、10.41%、23.12%と上昇した。spread/ATR percentileはQ1 21.55%からQ4 1.88%へ低下した。相対ATRとspread/ATRは候補featureだが、同じMarch標本で発見・評価しているため、`ATR_PERCENTILE_NORMALIZATION_PROMISING_IN_DEVELOPMENT_SAMPLE` に留める。tick activityは値が強く離散化され、Q3が空になるため、有効な連続順位featureとしては未確立である。

Continuation 84件とreversal 104件、high-movement内では各19件で、検知時点の方向選択根拠は得られなかった。新規MLはsample concentrationと再利用データのため実施していない。

## Horizon lag correction

各horizonへtarget time、実snapshot quote time、lagを保存した。30,000msまでは採用し、30,001ms以上は `CENSORED_HORIZON_LAG` としてそのhorizon以降のcomplete-path推論から除外した。46 episodeがlag censor、2 episodeがend-of-data censor。利用可能扱いの30秒超lagは0。production-path harnessは境界30,000ms採用と30,001ms censorを含め11/11 PASS。

## Tick quality

GBPUSDのtester journalは「179 discarded minutes / 30,187 total tester minutes」を示し、EA側M1観測は30,188分だった。この2つは母集団定義が異なるため統一せず併記する。区間mapがないためGBPUSDはrelative analysisから除外した。他5通貨ではdiscard warningを観測しなかったが、warning不在を完全real-tick保証とは扱わない。

## QA

- research EA compile: 0 errors / 0 warnings
- post-shock production-path harness: 11 PASS / 0 FAIL
- deterministic component suite: 407 PASS / 0 FAIL / 9 terminal-only SKIP
- independent oracle: 20 PASS / 0 FAIL
- behavior comparison: detector 21,799、episode 3,151、complete excursion 3,103で意図しない差分0
- causal violation、duplicate episode、invalid Bid/Ask、future feature read、available horizon overshoot、order/trade: 各0
- capacity: post-shock/event/merge capacity hit 0、drop 0、cursor stall 0

既知のQA制約として、`run_all_tests.ps1` は `step15h` phaseをValidateSetで拒否したため、MQL harness runnerとPython runnerを個別実行した。このrunner整合性は未修正findingであり、分析結果をPASSへ偽装しない。

## 次のpromotion gate

現在の45セルからbest cellを選ばず、まずrunner phase整合性とGBPUSD provenanceを解決する。その後、事前固定した少数の経済的幾何と候補featureを、未使用期間でcluster-awareに検証する。OOS前にthreshold、direction、symbolをMarch結果へ合わせない。Expectancy、commission込みnet R、実注文可能性は本Stepの対象外である。

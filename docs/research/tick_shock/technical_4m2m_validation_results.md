# 1～4月学習EA：5～6月MT5検証結果

## 結論

学習結果を固定した別EAを作成し、5月・6月のStrategy Tester検証を完了した。
**本番候補には昇格しない。** 月200取引という目的を満たさない診断用候補であり、
1～4月内の選定時点でも安定性・近隣しきい値の合格条件を満たす候補は0だった。

## 実MT5成績（観測されたcommission・fee・swapを含む）

|期間|取引数|勝率|損益 USD|Expectancy R|PF（金額）|最大確定損益DD USD|
|---|---:|---:|---:|---:|---:|---:|
|202505|46|43.5%|-6.92|-0.0173|0.940|29.09|
|202506|25|36.0%|-13.20|-0.0574|0.755|38.61|

合計：71取引、-20.12 USD、Expectancy -0.0314R。
各月10,000 USDから独立開始。結合DDは月別曲線を接続した固定リスク診断で、連続口座運用やequity DDとは異なる。

## 作ったEA

`mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnical4m2mCandidate.mq5` / `.ex5`

- frozen TAIL_V1_PERSISTENT detector、486因果的特徴量、確定M1/M5/M15 bar。
- LONG/SHORT別正則化ロジスティック回帰。期待Rの高い側が0.1R以上なら選択、他はNO TRADE。
- TP＝SL＝2×確定M5 ATR14、最低3スプレッド、900秒から時間決済を要求（下記の実超過あり）。
- 全通貨合計1ポジション。最大10 USDリスク（equityの0.25%上限も適用）。
- Strategy Tester以外は初期化失敗。実運用EAではない。

モデル選定・特徴量の説明は `docs/research/tick_shock/technical_4m2m_learning_results.md`。
主要係数はM5 EMA価格乖離/傾き、M15 SMA傾き、RSI変化、時間足間interaction等。
モデル係数は独立した利益要因や因果関係を意味しない。

## 検証手順と証跡

1. 1～2月学習→3月評価、1～3月学習→4月評価。108候補を固定gridで比較。
2. 診断候補を1つ固定し、1～4月へ再学習。5～6月は一切選定に不使用。
3. モデルJSON・MQL・EA・presetのハッシュを保存。モデル独立再計算、MT5推論11,230件一致。
4. 初回のcallback接続漏れを無効試行として保存。既存callbackを接続し、1月2日の実処理3件一致を確認。
5. 同じ重み/特徴/しきい値/geometryで5月→6月をModel4、EURUSD M1、Bybit-Liveで実行。
6. 実約定・CSV・HTML損益・独立推論・因果時刻・数量を照合。

集約QA：52項目、FAIL 0。最終compileはcandidate/harnessとも0 errors / 0 warnings。
取引件数までの完全一致を推論一致と混同しない。`python_mt5_comparison_counts.csv` と月別比較CSVを参照。
現在quoteでの注文、serverのTP/SL、時間決済の次tickによる差は比較CSVへ残した。

5月はPythonの47件に対してMT5は46件。差の1件はUSDJPYの `NO_ENTRY_TIMEOUT`。6月は両方25件。
全3,889エピソードの方向/スコアと特徴量は一致し、損益・約定が完全一致したという意味ではない。
実保有時間は最大906.491秒、900秒超過は54件。厳密な15分以内は未達。
これは `hold_time_overruns.csv` と `limitations.csv` へ残し、PASSへ含めない。コードを結果に合わせて修正していない。

実commission合計 0.00 USD、fee 0.00 USD、swap 0.00 USD。
ゼロは当該testerで観測されたdealの値であり、他口座やライブでもゼロとの保証ではない。
追加0/0.1/0.2/0.5/1 pip往復ストレスは `cost_sensitivity.csv`。既存Bid/Askスプレッドとは別の仮定。

実行時間は5月22分18.676秒、6月16分19.573秒。MT5報告メモリは787/843MB。
CSV容量・採取したプロセスメモリは `run_resources.csv`。再学習や無効試行の時間はこのtester時間に含めない。

## 制約と次の判断

- 1～4月での再学習後、頻度が月28～77件へ落ちた。月200件の成立は未確認。
- 月内fitted利益だけで候補を採用すると、この不安定性を見落とす。
- January/April旧pool警告は保持。Technical収集だけの合格をglobal VALIDATEDへ昇格しない。
- 2月/3月の一部区間に生成ティック置換が記録されている。純粋実ティック100%の主張はしない。
- 月別起動warmup・月末censoringがある。May/Juneは今回の固定holdoutであり、普遍的未使用OOSとは呼ばない。
- partial fill・ライブ約定・再起動復元・他broker運用は本試験で保証しない。
- 同じ5～6月に合わせたしきい値調整・追加候補の探索は行っていない。
- この1候補を資金投入対象にしない。目的を達成するには、今回の失敗理由を踏まえた別の事前仕様と新しい検証期間が必要。

## 主要ファイル

- `reports/analysis/tick_shock/technical_4m2m_real/`：学習・選定・固定モデル・独立再計算。
- `reports/backtest/batches/tstech_4m2m_validation_r2_20260911/202505/`：5月実MT5。
- `reports/backtest/batches/tstech_4m2m_validation_r2_20260911/202506/`：6月実MT5。
- 同batchの `actual_monthly.csv`、`qa_checks.csv`、`cluster_bootstrap.csv`、`source_hashes.csv`。
- `docs/devlog/2026-09-11-tickshock-4m2m-ea-validation.md`：実装経緯と無効試行。

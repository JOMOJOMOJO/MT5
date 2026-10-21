# r2結果確認：費用差で停止、9本未完了

対象run: `runs/20261009_153348_619497c2`。元のFAILED状態と照合ルールは変更していない。

## 結論

- 4ソースcompile 0 errors / 0 warnings。
- ハーネス18項目合格。
- daily_legacy_clockのMT5実行は終了したが、費用完全一致の監査で停止。
- 実行済みの14約定はCSVと標準レポートで一致。欠損・余分・重複0。
- 旧版の7取引と時刻・銘柄・方向・価格・volume・SL/TP・profit・commission・fee・reasonは一致。
- 違いはEURUSDの2決済のswapだけ：−1.35→−1.32 USD、−0.68→−0.66 USD。合計差+0.05 USD。
- 旧版net −48.34 USD、今回net −48.29 USD。今回PF 0.1424、勝率2/7、平均fill-price R −0.3411。
- コードがEntryを変えたことを示す差ではない。ただしswapが変化した元原因（銘柄条件・換算等）は未確定。差を無視して合格にはしていない。

## 完了範囲

|検証|状態|
|---|---|
|harness|18項目合格|
|daily_legacy_clock|7取引実行、約定CSV照合合格、旧版とのswap一致は不合格|
|daily_timer|未実行|
|M5 USDJPY reference/portable|未実行|
|M5 EURUSD reference/portable|未実行|
|M5 XAUUSD reference/portable|未実行|

前回欠損したタイマー版は今回未実行。今回の旧時計版で欠損がないことを、タイマー問題の修正成功とは扱わない。
最終履歴ログはnarrow=15/all=15/captured=14（balanceを除いた売買14件）。旧時計では窓拡張による増分はない。
テストの価格データは全銘柄GENERATED_TICKS、既知の2023年1〜3月。利益改善や汎用性の最終確認ではない。
現在、当該QAのMT5は稼働していない。今回の確認では再起動・売買コード変更・最適化を行っていない。

## 次の切り分け

旧版・修正版を同一実行時点の銘柄条件で対にし、swap条件・換算条件の記録を加えて比較する。
古いレポートとの価格・シグナル再現と、現在条件下での費用再現を明確に分ける。
タイマー版の欠損修正とM5 3銘柄の一致確認が終わるまで、最適化・売買フィルター追加・本番採用へ進まない。

## 証拠

- [run status](runs/20261009_153348_619497c2/status.json)
- [差分の全項目](runs/20261009_153348_619497c2/daily_legacy_clock/execution_parity.json)
- [deal coverage](runs/20261009_153348_619497c2/daily_legacy_clock/deal_coverage.json)
- [最終履歴時計](runs/20261009_153348_619497c2/daily_legacy_clock/final_history_clocks.json)
- [7取引明細](runs/20261009_153348_619497c2/daily_legacy_clock/trades.csv)
- [標準レポート](runs/20261009_153348_619497c2/daily_legacy_clock/report.htm)

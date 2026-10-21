# Bybit 2023 履歴再取得後の再検証

2026-10-01確認。処理は正常完了。専用端末ログでBybit-Liveへの認証を確認した。既存端末から2022/2023のUSDJPYバー履歴をコピーし、旧Testerキャッシュを持たない専用端末でModel=4を実行した。売買EA・Shared・条件は変更していない。

## 結果

- 全READY shadow候補192件、TP74件、SL118件。
- 旧Bybit annual_2023と、M1バーCSV、Entry quote、shadow損益経路、shadow結果がバイト単位で完全一致。
- 実tickによる追加学習ラベルは0件。

## 原因を示すログ

tester.logに次の明示的な記録がある。

`USDJPY : 2023.01.01 00:00 - 2024.01.01 00:00  no real ticks, every tick generation used`

今回は日別の破棄警告による保守的な除外ではなく、対象年全体が実tickなしで生成tickによる実行だった。品質JSONのreal_tick_begin=null / warning_days=[]は品質良好を意味しない。このログを優先して解釈する。

取り込めた対象期間のファイルはバー履歴の2022.hcc/2023.hcc。2023年の実tickファイルはなかった。ローソク足履歴と実tick履歴は別であり、今回の再取得・実行では実tickの追加を確認できなかった。サーバーに存在しないのか、口座・配信範囲など別の要因なのかまでは、この実行だけでは断定できない。

生成tick結果は診断資料として保持するが、実tickでTP/SL到達順序を保証した教師データとして追加しない。新たなテストは起動していない。

証拠: [tester.log](tester.log)、[品質監査](collection_quality.json)、[コピー元履歴](../bybit_2023_refresh_20261001_job/source_history_inventory.json)。

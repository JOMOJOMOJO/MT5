# M15環境の表示・診断追加

売買EAへM15環境パネル、構造範囲の水平線、READY/Entry固定ラベルと独立CSVを追加した。売買の許可・拒否や価格計算には使用しない。

研究再生EAと表示機能は同一の `M15Environment.mqh` を使用する。既存Python研究との119候補・34,623本の照合を通過。2025年1月のREADYおよびHL再接近モードで、変更前後の売買CSVと最終残高が一致した。最終描画調整後の短期再実行も一致。コンパイル0 errors / 0 warnings。

現在パネルと過去Entryの状態が異なる場面を実画面で確認し、過去ラベルが固定されることを確認した。ライブ再起動の復元試験は未実施。

- [検証報告・差分・CSV・画面](../../reports/qa/three_wave/m15_display_integration/summary.md)
- [共通定義と不変性の確認方法](../../knowledge/experiments/m15-display-observer-20260929.md)

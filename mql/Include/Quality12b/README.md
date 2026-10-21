# Quality12b EA モジュール

起点は `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`。OnInit / OnDeinit / OnTimer / OnTradeTransaction / OnTickは起点ファイルへ残す。

| ファイル | 担当 |
| --- | --- |
| Configuration.mqh | 型・163input・実行状態 |
| RuntimeRisk.mqh | 文字列/曜日、価格単位、スプレッド、ロット、日次リスク制限 |
| MarketData.mqh | 各戦略のローソク足・指標バッファ取得 |
| PositionManagement.mqh | Magic/銘柄別ポジション、時間決済、エントリー可否 |
| PriceStructure.mqh | ピボット・ローソク形状・レンジ状態 |
| Signals.mqh | 各bucketの売買シグナル |
| Orders.mqh | bucket別SL/TPと注文発行 |
| TelemetryControl.mqh | 約定記録・日次集計・運用コマンド・状態表示 |

今回の分割は意味を変えない移動のみ。include順序、宣言順序、関数本文、input名/順序/初期値、Magic、ファイル名、バージョンを保存する。未使用bucketも他プリセットとの互換性のため保持する。

元EAを編集するときは対応モジュールを編集する。メインファイルだけを別環境へコピーして再コンパイルしないこと。`mql/Experts` と `mql/Include/Quality12b` の相対位置を維持する。コンパイル済みEX5に外部mqh配布は不要。

既存の設定ファイルはそのまま使用可能。スプレッド境界、SL/TP、リスク計算の挙動は今回変更していない。これらの修正は別の差分・検証として実施する。

`python tools/quality12b/refactor_modules.py` はモジュールを再結合して分割前の凍結ソースとバイト一致を検証する。将来の意図的なロジック修正では一致しなくなるため、その際は別の仕様テスト/MT5結果で検証する。

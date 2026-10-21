# 汎用化QA r2：終了時の約定収集を修正

## 変更範囲

[前回の9本計画](../portable_audit_20261008/plan.md)の銘柄・期間・売買条件・順序をすべて維持する。
今回の追加差分は、テスター終了時の約定履歴収集と、その監査だけ。旧版の失敗成果物は保存した。
本番EA・既存Shared・旧研究EAは変更しない。研究後継版の日足EAのみ、新しい観測Includeを参照する。

## 観測した不一致

[前回run](../portable_audit_20261008/runs/20261008_175938_81b17f66/status.json)はdaily_timerで停止。
MT5標準レポートは14約定、CSVは12約定。欠損はdeal 14（GBPUSD決済）と15（EURUSD決済）。
ジャーナルで両方が2023-03-31 23:59:50の `position closed due end of test` と確認できる。
欠損を除外して合格扱いにはせず、売買条件にも変更を加えない。

旧observerの `HistorySelect(0,TimeCurrent())` は最終quote時計までしか収集しない。
タイマーによるテスト終端がその時刻を超えることを疑い、終了済みテスターのOnTester/OnDeinitだけ、既に作られた全約定履歴を収集する。
通常イベントの時刻制約は維持。価格履歴を未来まで読む変更ではなく、収集結果も売買判定へ戻さない。
最終quote時計・server時計・従来窓件数・全履歴件数・最新deal時刻をログへ出し、再実行で原因を確定する。
現段階では収集範囲による原因は仮説で、修正有効性は再実行待ち。

- [TimeCurrent公式定義](https://www.mql5.com/en/docs/dateandtime/timecurrent)
- [HistorySelect公式定義](https://www.mql5.com/en/docs/trading/historyselect)
- [observer差分](observer.diff)

## 既に合格した範囲

- 前回ハーネス：MT5上で18項目合格。
- 前回daily_legacy_clock：7取引、旧版と約定・価格・SL/TP・費用が一致。
- 前回の日足risk.csv：XAUUSDの14計算行は全てMIN_VOLUME_EXCEEDS_RISK。指定0.25%で最小lotを許容できる計算上のEquityは16,268〜24,296 USD（口座10,000 USD）。資金増加やリスク増加を推奨する結果ではない。
- Python：従来5件＋追加4件合格。実際の欠損14/15を検出する回帰テストを含む。
- [r2コンパイル](preflight/20261009_153207_3ad9f4f6/status.json)：4ソースすべて0 errors / 0 warnings。

## 合格条件と停止方針

標準レポートとCSVの全deal ID・金額・件数照合を維持する。足りない決済をHTMLから補完したり、quoteを推測しない。
日足旧時計の一致、M5のUSDJPY/EURUSD/XAUUSDそれぞれの旧版との売買一致、因果時刻・リスク上限・環境分類の一致を監査する。
全9本を再実行して再現性を確認する。失敗時は次のrunへ進まない。
MT5は独立portable。現在開いているMT5には触れない。起動後はCodexが待機を続けず、ユーザーの完了連絡を待つ。
これは工学QAであり、収益性・本番採用・最適化の結果ではない。

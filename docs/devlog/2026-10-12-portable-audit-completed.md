# 汎用化QA r5完了

完了通知を受け、status、10件のaudit、M5全3ペアの比較、compile、保護hashを確認した。残るEURUSD/XAUUSDの4本も正常終了し、再利用6本と合わせて全10本合格。

## 得られた結論

- M5新旧140取引一致。観測・リスク計算の汎用化による意図しない売買差をこの期間では検出しなかった。
- USDJPY49件・EURUSD36件はマイナス、XAUUSD55件は＋73.63 USD/PF1.052。これだけで利益優位性を確立したとは扱わない。
- 毎月20回を満たす銘柄なし。spreadはFX2銘柄の見送りに多く関与するが、ゴールドの見送りをspreadだけでは説明できない。
- M5の固定QA設定は0.65%リスク・SL2.2ATR・TP1.5R。ユーザーの以前の1%要求や3波EAのRRと混同しない。

## 作成物

`tools/quality12b/summarize_portable_audit_r5.py` は保存済み結果の記述集計だけを行う。売買コード、input、旧監査、過去runは変更しない。
CSVへ月別結果・シグナルから発注までの内訳・ペア一致・入力hashを保存。新MT5バッチは起動していない。

## 証拠と判断

- [最終報告](../../reports/qa/portable_audit_20261012_r5/runs/20261012_120220_f6be2b8d/review/summary.md)
- [QA判断](../../.company/qa/2026-10-12-portable-audit-r5-review.md)
- [既存の汎用化の教訓](../../knowledge/lessons/2026-10-08-multi-asset-generalization-and-regime-meaning.md)

このサイクルを工学QA合格で閉じる。利益・頻度目標は未達であり、閾値緩和や新規複合条件の採用へ自動的に進めない。新しい外向け記事seedは今回は追加せず、既存の汎用化の教訓と証拠を結び付ける。
